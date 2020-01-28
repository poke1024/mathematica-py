import sys
import inspect

from wolframclient.language import wlexpr
from wolframclient.language.expression import WLFunction

import types
import collections

class PyState:
	def __init__(self):
		self._handle = 0
		self._objs = dict()
		self._scopes = [set()]

	def _check_handle(self, h):
		if not isinstance(h, int):
			raise RuntimeError('PyHandle[%s] is not valid' % h)
		if h not in self._objs:
			raise RuntimeError('PyHandle[%s] is not valid' % h)

	def put(self, obj):
		h = id(obj)
		if h not in self._objs:
			self._objs[h] = obj
			self._scopes[-1].add(h)
		return h

	def get(self, h):
		self._check_handle(h)
		return self._objs[h]

	def free(self, h):
		self._check_handle(h)
		del self._objs[h]

	def size(self):
		return len(self._objs)
	
	def enter_scope(self):
		self._scopes.append(set())

	def exit_scope(self):
		s = self._scopes.pop()
		for h in s:
			del self._objs[h]

global py_state
py_state = PyState()

def py_enter_scope():
	global py_state
	py_state.enter_scope()

def py_exit_scope():
	global py_state
	py_state.exit_scope()

def _py_map_args(args):
	global py_state
	for arg in args:
		if isinstance(arg, WLFunction):
			if arg.head.name == 'Py`PyHandle':
				handle = int(arg.args[0])
				arg = py_state.get(handle)
		yield arg

def _py_is_non_primitive(x):
	return hasattr(x, '__dict__') or hasattr(x, '__slots__')

def _py_wrap_result(r):
	if _py_is_non_primitive(r):
		return wlexpr('PyHandle[%d]' % py_state.put(r))
	elif isinstance(r, types.GeneratorType):
		return _py_wrap_result(list(r))
	elif isinstance(r, collections.abc.Sequence) and not isinstance(r, str):
		return type(r)([_py_wrap_result(x) for x in r])
	else:
		return r

def py_create_instance(klass, args):
	global py_state

	k = globals()

	parts = klass.split('.')
	for i, p in enumerate(parts):
		k = k.get(p)
		if k is None:	
			raise RuntimeError('could not resolve \'% s\'' % '.'.join(parts[:i + 1]))

	args = list(_py_map_args(args))
	obj = k(*args)

	return py_state.put(obj)

def py_call_method(handle, method, args):
	global py_state
	args = list(_py_map_args(args))
	r = getattr(py_state.get(handle), method)(*args)
	return _py_wrap_result(r)
	
def py_get_attr(handle, name):
	global py_state
	return _py_wrap_result(getattr(py_state.get(handle), name))

def py_free_handle(handle):
	global py_state
	py_state.free(handle)

def py_execute(expr):
	exec(compile(expr, "<string>", "exec"), globals())

def py_evaluate(expr):
	return _py_wrap_result(eval(expr, globals()))

def py_import(path, name, syms):
	import sys
	if path not in sys.path:
		sys.path.insert(0, path)
	import importlib
	m = importlib.import_module(name)
	for s in syms:
		globals()[s] = getattr(m, s)

def py_handle_count():
	global py_state
	return py_state.size()
