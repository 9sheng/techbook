# C++0x学习之简洁语法

### 模块尖括号

`list<vector<string>> lvs;`可以正确解析了，不用再这样写了：`list< vector<string> > lvs;`(注意`> >`之间的空格)。

### 循环迭代器
迭代器遍历更方便的写法，想到 foreach了吗？
```cpp
void f(vector<double>& v) {
  for (auto x : v) cout << x << '\n';
  for (auto& x : v) ++x;	// 使用引用，方便我们修改容器中的数据
}

for (const auto x : { 1,2,3,5,8,13,21,34 })
  cout << x << '\n';
```

### 初始化列表
初始化列表可以是任意长度，但必须是同质的（所有的元素必须属于某一模板类型T, 或可转化至T类型的)，内部使用了 `initializer_list`。仅具有一个 `std::initializer_list` 的单参数构造函数被称为初始化列表构造函数。

```cpp
vector<doublev = { 1, 2, 3.456, 99.99 };
list<pair<string,string>> languages = {
  {"Nygaard","Simula"}, {"Richards","BCPL"}, {"Ritchie","C"}
};

map<vector<string>,vector<int>> years = {
  { {"Maurice","Vincent", "Wilkes"},{1913, 1945, 1951, 1967, 2000} },
  { {"Martin", "Ritchards"}, {1982, 2003, 2007} }, 
  { {"David", "John", "Wheeler"}, {1927, 1947, 1951, 2004} }
};

vector<double> v1(7);   // 正确: v1有7个元素
v1 = 9;                 // 错误: 无法将int转换为vector
vector<double> v2 = 9;  // 错误: 无法将int转换为vector

vector<vector<double>> vs = {
  vector<double>(10),   // 正确: 显式构造（10个元素，值为double的默认值） 
  vector<double>{10},   // 正确：显式构造（1个元素，值为10） 
  10                    // 错误 ：vector的构造函数是显式的
};
```
### nullptr：空指针标识
```cpp
char* p = nullptr;
int*  q = nullptr;
char* p2 = 0;     // 这里 0 的赋值还是有效的，并且 p == p2
void g(int);
g(nullptr);       // 错误：nullptr 并不是一个整型常量
int i = nullptr;  // 错误：nullptr 并不是一个整型常量
```

### 统一初始化的语法和语义
看下面的代码，是函数声明还是变量定义，你搞晕了吧！
```cpp
int a(1);	// 变量定义
int b();	// 函数声明
int b(foo);	// 变量定义或函数声明都有可能
```
c++0x中统一可以通过 `{}` 初始化

```cpp
X x1 = X{1,2}; 
X x2 = {1,2}; 	// the = is optional
X x3{1,2}; 
X* p = new X{1,2}; 
```
这样也可以：
```cpp
X x{a};
X* p = new X{a};
z = X{a};         // 使用了类型转换
f({a});           // 函数的实际参数（X类型的）
return {a};       // 函数的返回值（函数返回类型为X）
```

### 原生字符串标识
为了转义字符，看了这个估计要崩溃了吧：
```cpp
"('(?:[^\\\\']|\\\\.)*'|\"(?:[^\\\\\"]|\\\\.)*\")|"  // 这五个反斜杠是否正确?
```
现在可以这样写原生字符串了（`R"PATTERN("` 和 `")PATTERN"` 之间为实际字符串， PATTERN 为自定义标识符，为什么不来 here document 呢？）：

```cpp
R"("quoted string")"	// 字符串为 "quoted string"
// 字符串为 "quoted string containing the usual terminator (")"
R"***("quoted string containing the usual terminator (")")***"
```

### Lambdas

```cpp
vector<intv = {50, -10, 20, -30};

std::sort(v.begin(), v.end());	// 使用默认排序函数
// v 现在是 { -30, -10, 20, 50 }

// 使用绝对值排序
std::sort(v.begin(), v.end(), [](int a, int b) { return abs(a)<abs(b); });
// v 现在是 { -10, 20, -30, 50 }
```
`[]` 是一个“捕捉列表(capture list)”，即调用lambda所在函数的变量。不使用则为 `[]`；使用引用则为`[&]`；传值则为`[=]`。下面例子：

```cpp
void f(vector<Record>& v)
{
	vector<intindices(v.size());
	int count = 0;
	generate(indices.begin(), indices.end(), [&count](){ return count++; });

	// sort indices in the order determined by the name field of the records:
	std::sort(indices.begin(), indices.end(), [&](int a, int b) { return v[a].name<v[b].name; });
	// ...
}
```
如果一个函数的行为既不一般也不简单，最好使用具名函数或函数对象。如：

```cpp
void f(vector<Record>& v) {
  vector<intindices(v.size());
  int count = 0;
  generate(indices.begin(), indices.end(), [&](){ return ++count; });

  struct Cmp_names {
    const vector<Record>& vr;
    Cmp_names(const vector<Record>& r) :vr(r) { }
    bool operator()(int a, int b) const { return vr[a].name < vr[b].name; }
  };

  // sort indices in the order determined by the name field of the records:
  std::sort(indices.begin(), indices.end(), Cmp_names(v));
  // ...
}
```
