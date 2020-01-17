class AnotherClass:
	def __init__(self, x):
		self._x = x

class MyDemoClass:
	def __init__(self, x):
		self._x = x

	def compute(self, y):
		return self._x + y

	def complex(self):
		return AnotherClass(self._x)
