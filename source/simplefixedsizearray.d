module simplefixedsizearray;

struct SFA(T,size_t Size = 32) {
	static assert(Size > 0);
	import std.traits : CopyTypeQualifiers, hasElaborateDestructor, hasMember;

	size_t length;
	ubyte[T.sizeof * Size] store;

	~this() {
		static if(hasElaborateDestructor!T) {
			this.removeAll();
		}
	}

	struct SFARange(S,U) {
		S* ptr;
		size_t low;
		size_t high;

		@property bool empty() const pure @safe nothrow @nogc {
			return this.low >= this.high;
		}

		pragma(inline, true)
		@property size_t length() pure @safe nothrow @nogc {
			return cast(size_t)(this.high - this.low);
		}

		@property ref U front() {
			return (*this.ptr)[this.low];
		}

		@property ref U back() {
			return (*this.ptr)[this.high];
		}

		ref T opIndex(const size_t idx) {
			return (*this.fsa)[this.low + idx];
		}

		void popFront() pure @safe nothrow @nogc {
			++this.low;
		}

		void popBack() pure @safe nothrow @nogc {
			--this.high;
		}

		@property typeof(this) save() pure @safe nothrow @nogc {
			return this;
		}
	}

	SFARange!(typeof(this), CopyTypeQualifiers!(S,T)) opSlice(this S)(size_t low, size_t high) {
		assert(low <= high);
		assert(low <= this.length);
		return typeof(return)(&this, low, high);
	}

	@property bool empty() const @safe @nogc nothrow {
		return this.length == 0U;
	}

	@property bool hasCapacity() const @safe @nogc nothrow {
		return (this.length * T.sizeof) < this.store.length;
	}

	void insertBack(T t) {
		assert(this.length + 1 <= Size);
		*(cast(T*)(&this.store[cast(size_t)(this.length * T.sizeof)])) = t;
		++length;
	}

	ref CopyTypeQualifiers!(S,T) opIndex(this S)(size_t idx) {
		idx *= T.sizeof;
		assert(idx < this.store.length);
		return *(cast(T*)&(this.store[idx]));
	}

	@property ref CopyTypeQualifiers!(S,T) front(this S)() {
		assert(!this.empty);
		return *(cast(T*)(&this.store[0U]));
	}

	@property ref CopyTypeQualifiers!(S,T) back(this S)() {
		import std.stdio;
		assert(!this.empty);
		return *(cast(T*)(&this.store[(this.length * T.sizeof) - T.sizeof]));
	}

	void removeAll() {
		while(!this.empty) {
			this.removeBack();
		}
	}

	void removeBack() {
		assert(!this.empty);

		static if(hasElaborateDestructor!T) {
			static if(hasMember!(T, "__dtor")) {
				this.back().__dtor();
			} else static if(hasMember!(T, "__xdtor")) {
				this.back().__xdtor();
			} else {
				static assert(false);
			}
		}

		--this.length;
	}

	void remove(size_t idx) {
		assert(idx < this.length);
		static if(hasElaborateDestructor!T) {
			static if(hasMember!(T, "__dtor")) {
				this[idx].__dtor();
			} else static if(hasMember!(T, "__xdtor")) {
				this[idx].__xdtor();
			} else {
				static assert(false);
			}
		}

		for(size_t i = idx * T.sizeof; i < ((this.length - 1U) * T.sizeof); ++i) {
			this.store[i] = this.store[i + T.sizeof];
		}

		--this.length;
	}
}

unittest {
	SFA!(int) a;
}

unittest {
	SFA!(int) a;
	assert(a.hasCapacity);
	a.insertBack(10);
	assert(a[0] == 10);
	assert(a.front == 10);
	assert(a.back == 10);
	a.removeBack();
	assert(a.empty);
}

unittest {
	struct Foo {
		size_t value;
		alias value this;

		~this() {
		}
	}

	void test(size_t Size, T)() {
		SFA!(T, Size) a;
		assert(a.empty);
		foreach(it; 0 .. Size) {
			assert(a.hasCapacity);
			a.insertBack(T(it));
			assert(a.length == it + 1);
			assert(a.front == 0);
			assert(a.back == it);

			foreach(jt; 0 .. it + 1) {
				assert(a[jt] == jt);
			}

			auto r = a[0 .. a.length - 1];
			assert(r.front == 0);
			assert(r.back == it);
		}
		assert(!a.hasCapacity);
	}

	static foreach(tSize; [1,2,3,4,5,10,11,32,63,64]) {
		test!(tSize, size_t)();
		test!(tSize, Foo)();
	}
}

unittest {
	import std.stdio;
	SFA!(int) a;
	foreach(it; [0,1,2,3,4,5,6,7,8,9]) {
		a.insertBack(it);
	}

	a.remove(5);

	foreach(idx, it; [0,1,2,3,4,6,7,8,9]) {
		assert(a[idx] == it);
	}
}

unittest {
	SFA!int a;
	a.insertBack(1337);
	a.remove(0);
	assert(a.empty);
}
