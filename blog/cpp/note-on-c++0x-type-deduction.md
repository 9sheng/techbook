# C++0x 学习之类、函数

### 控制默认函数：默认或者禁用
还记得如何禁止拷贝构造函数和赋值函数么？ C++98 中，你可能这样写:

```cpp
// A macro to disallow operator=
// This should be used in the private: declarations for a class.
#define GTEST_DISALLOW_ASSIGN_(type)\
  void operator=(type const &)

// A macro to disallow copy constructor and operator=
// This should be used in the private: declarations for a class.
#define GTEST_DISALLOW_COPY_AND_ASSIGN_(type)\
  type(type const &);\
  GTEST_DISALLOW_ASSIGN_(type)
```

c++0x 中可以明确指出来：

```cpp
class X {
  // ...
  X& operator=(const X&) = delete;  // 禁用拷贝构造函数
  X(const X&) = delete;
};

class Y {
  // ...
  Y& operator=(const Y&) = default;  // 使用默认赋值函数
  Y(const Y&) = default;
};
```

### 控制默认函数:移动(move)或者复制(copy)
在默认情况下，一个类拥有 5 个默认函数或操作符：

- 拷贝赋值操作符（copy assignment）
- 拷贝构造函数（copy constructor）
- 移动赋值操作符（move assignment）
- 移动构造函数（move constructor）
- 析构函数（destructor）

如果显式地指明（声明，定义，=default，或者 =delete）了移动、复制或者析构函数，将不会产生默认的移动操作（移动赋值操作符和移动构造函数），同时未声明的复制操作（复制赋值操作符和复制构造函数）也会被默认生成。

如果声明了上述 5 个默认函数中的任何一个，强烈建议你显式地声明所有这 5 个默认函数。

```cpp
template<class T>
class Handle {
  T* p;
public:
  // 构造函数
  Handle(T* pp) : p{pp} { }
  // 用户定义析构函数，没有隐式的复制和移动操作
  ~Handle() { delete p; } 

  // 转移构造函数，传递所有权
  Handle(Handle&& h) :p{h.p} { h.p=nullptr; };
  // 转移赋值函数，传递所有权
  Handle& operator=(Handle&& h) { delete p; p=h.p; h.p=nullptr; return *this; }

  // 拷贝构造函数
  Handle(const Handle&) = delete;
  // 拷贝赋值函数
  Handle& operator=(const Handle&) = delete;

  // ...
};
```

### 右值引用
左值（赋值操作符“=”的左侧，通常是一个变量）与右值（赋值操作符“=”的右侧，通常是一个常数、表达式、函数调用）。在 C++ 中，左值可被绑定到 const 或非 const 引用；右值只能绑定到 const 引用。是为了防止人们修改临时变量的值，这些临时变量在被赋予新的值之前，都会被销毁。`&&` 表示“右值引用”。右值引用可以绑定到右值（但不能绑定到左值）：

```cpp
X a;
X f();
X& r1 = a;      // 将r1绑定到a(一个左值)
X& r2 = f();    // 错误：f()的返回值是右值，无法绑定
X&& rr1 = f();  // 正确：将rr1绑定到临时变量
X&& rr2 = a;    // 错误：不能将右值引用rr2绑定到左值a
```

`move(x)` 意味着“你可以把x当做一个右值”

```cpp
template<class T>
void swap(T& a, T& b)  // "perfect swap" (almost)
{
  T tmp = move(a);  // could invalidate a
  a = move(b);  	// could invalidate b
  b = move(tmp);  	// could invalidate tmp
}
```
### 委托构造函数
c++0x中构造函数可以互相调用了，如：

```cpp
class X
{
  int a;
public:
  X(int x) { if (0<x && x<=max) a=x; else throw bad_X(x); }
  X() :X{42} { }
  X(string s) :X{lexical_cast<int>(s)} { }
  // ...
};
```

### 类成员的内部初始化
现在也允许非静态（non-static）数据成员在其声明处（在其所属类内部）进行初始化。这样，在运行过程中，需要初始值时构造函数可以使用这个初始值。如果一个成员同时在类内部初始化时和构造函数内被初始化，则只有构造函数的初始化有效（这个初始化值“优先于”默认值），示例如下：

```cpp
class A {
public:
  A() {}
  A(int a_val) : a(a_val) {}
  A(D d) : b(g(d)) {}
  int a = 7;
  int b = 5;	
private:
  HashingFunction hash_algorithm{"MD5"};  // Cryptographic hash to be applied to all A instances
  std::string s{"Constructor run"};       // String indicating state in object lifecycle
};
```

### 继承的构造函数
c++0x中可以直接继承基类的构造函数了。如下例所示：

```cpp
class Derived : public Base {
public:
  // 提升Base类的f函数到Derived类的作用范围内
  // 这一特性已存在于C++98标准内
  using Base::f;    
  void f(char); // 提供一个新的f函数
  void f(int);  // 与Base类的f(int)函数相比更常用到这个f函数

  // 提升Base类的构造函数到Derived的作用范围内
  // 这一特性只存在于C++11标准内
  using Base::Base;
  Derived(char);    // 提供一个新的构造函数    
  // 与Base类的构造函数Base(int)相比
  // 更常用到这个构造函数
  Derived(int);     
  // ...
};
```

注意，如果子类有父类没有的变量，该如何初始化呢？可以借助“类成员的内部初始化”

```cpp
struct D1 : B1 {
  using B1::B1;    // 隐式声明构造函数D1(int)
  int x{0};        // 注意：x变量已经被初始化
};

void test()
{
  D1 d(6);         // d.x的值是 0
}
```

### 重写(override)的控制
在 C++11 中，可以使用新的 override 关键字，来让程序员可以更加明显地表明他对于重写的设计意图，增加代码的可读性。

```cpp
struct B {
  virtual void f();
  virtual void g() const;
  virtual void h(char);
  void k();      // 非虚函数
};

struct D : B {
  void f() override;     // 正确: 重写 B::f()
  void g() override;     // 错误: 不同的函数声明，不能重写
  virtual void h(char);  // 重写 B::h(char); 可能会有警告
  void k() override;     // 错误: B::k() 不是虚函数
};
```

有时候，可能想要阻止某个虚函数被重写，在这种情况下，他可以为虚函数加上final关键字来达到这个目的。例如：

```cpp
struct B {
virtual void f() const final; // 不能重写
virtual void g();             // 没有final关键字，可以重写
};

struct D : B {
  void f() const; // 错误: D::f尝试重写final修饰的B::f会产生编译错误
  void g();       // OK
};
```
