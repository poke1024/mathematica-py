(* ::Package:: *)

BeginPackage["Py`"]

PyStart::usage=
	"PyStart[env] starts a global Python session with the conda
	environment env.";
	
PyImport::usage=
	"PyImport[sym] imports a Python symbol.";

PyClass::usage=
	"PyClass[name] specifies a Python class."
	
PyMethod::usage=
	"PyMethod[handle, name] specifies a callable class method
	called name inside the class instance referenced by handle."

PyGetAttr::usage=
	"PyGetAttr[handle, name] reads an attribute value of an object."

PyEvaluate::usage=
	"PyEvaluate[expr] evaluates expr in global Python session and
	returns the result.";

PyExecute::usage=
	"PyEvaluate[stmt] executes a statement or number of statements.";

PyDelete::usage=
	"PyDelete[handle] deletes the object instance attached to the
	given handle.";

PyHandle::usage=
	"PyHandle[handle] is an internal reference to a Python object.";

PyHandleCount::usage=
	"PyHandleCount[] yields the number of allocated handles.";

PyScoped::usage=
	"PyScoped[f] calls a function f inside an allocation scope, which
	means that all allocations happening inside f() will get freed
	automatically after leaving this scope.";

Begin["`Private`"]

PythonSession = Missing[];

PyCondaPaths[] := Join[
	Module[{prefix = Environment["CONDA_PREFIX"]},
		If[FailureQ[prefix], {}, {FileNameDrop[prefix, -2]}]],
	{
		$HomeDirectory <> "/anaconda3",
		$HomeDirectory <> "/miniconda3"
	}];

PyDetectCondaPath[] := 
	SelectFirst[PyCondaPaths[], StringQ[#] && FileExistsQ[#]&];

PyCheckResult[r__] := If[MatchQ[r,_Failure],{Print[r],Abort[]},r];

PyStart[env_, OptionsPattern[{"CondaPath" -> PyDetectCondaPath[]}]] :=
	PyStartFromPrefix[OptionValue["CondaPath"] <> "/envs/" <> env];

PyStartFromPrefix[condaPrefix_] :=
	Module[{
		PyClassInternal,
		PyMethodInternal,
		PyImportInternal,
		PyDeleteInternal,
		PyEvaluateInternal,
		PyExecuteInternal,
		PyGetAttrInternal,
		PyEnterScope,
		PyExitScope},

(* delete any previous python session *)
If[Not[MissingQ[PythonSession]],{
	DeleteObject[PythonSession];
	PythonSession=Missing[];
}];

(* start a new session with the specified environment *)
PythonSession = StartExternalSession[<|
	"System" -> "Python",
	"Executable" -> condaPrefix <> "/bin/python3"|>];

If[FailureQ[FindFile["Py`"]], Print["could not locate py.wl"]; Abort[]];

PyCheckResult[ExternalEvaluate[PythonSession,
	ReadString[FileNameDrop[FindFile["Py`"], -1] <> "/py.py"]]];

PyClassInternal = ExternalFunction[PythonSession, "py_create_instance"];
PyMethodInternal = ExternalFunction[PythonSession, "py_call_method"];
PyGetAttrInternal = ExternalFunction[PythonSession, "py_get_attr"];
PyEvaluateInternal = ExternalFunction[PythonSession, "py_evaluate"];
PyExecuteInternal = ExternalFunction[PythonSession, "py_execute"];
PyEnterScope = ExternalFunction[PythonSession, "py_enter_scope"];
PyExitScope = ExternalFunction[PythonSession, "py_exit_scope"];

PyClass[name_] := PyHandle[PyCheckResult[PyClassInternal[name, {##}]]]&;

PyMethod[PyHandle[handle_], name_] := 
	PyCheckResult[PyMethodInternal[handle,name,{##}]]&;

PyGetAttr[PyHandle[handle_], name_] := 
	PyCheckResult[PyGetAttrInternal[handle,name]];

PyDeleteInternal = ExternalFunction[PythonSession, "py_free_handle"];

PyImportInternal = ExternalFunction[PythonSession, "py_import"];

PyImport[syms_, OptionsPattern[{"From" -> "", "Path" -> NotebookDirectory[]}]] :=
	PyCheckResult[PyImportInternal[
		OptionValue["Path"],
		OptionValue["From"],
		If[ListQ[syms], syms, {syms}]]];

PyEvaluate = PyCheckResult[PyEvaluateInternal[#]]&;
PyExecute = PyCheckResult[PyExecuteInternal[#]]&;

PyDelete[PyHandle[handle_]] := PyDeleteInternal[handle];

PyHandleCount = ExternalFunction[PythonSession, "py_handle_count"];

PyScoped[f_] := Module[{},{
	PyEnterScope[];
	f[];
	PyExitScope[];
}];

]; (* end module *)

End[]

EndPackage[]



