
# randgenx

mysql的测试工具randgen的功能增强版本。

在看本文档之前最好具备randgen的基本使用知识，原版文档如下：

[randgen文档](https://github.com/RQG/RQG-Documentation/wiki/RandomQueryGeneratorQuickStart)

原版文档中有不少乱码，可以通过两次URL解码来解除乱码。等我有空会整理一个没有乱码的randgen的文档上传到这里来。


# 改动

## 能够直接生成Mysql的sql语句而不需要连接数据库


我通过增强之前的dummy数据源实现了该拓展，使用方法如下：

```shell
perl gentest.pl \
   --dsn=dummy:file:example.sql \
   --gendata=conf/example.zz \
   --grammar=conf/example.yy
```

当使用该特性时，`--threads`将会被强制设置成1,而不管用户原来设置的值。

`--queries`参数原本的含义是每个线程根据grammar生成的查询数，在这里`--threads`

## 直接在zz文件中指定datetime

研究了源码后发现，randgen其实原本就支持指定具体时间，虽然文档里没有明确说明，使用方法如下：

```perl
$tables = {
    rows => [2, 5, 8]
};

$fields = {
    types => ['date', 'time', 'year', 'datetime', 'timestamp']
};

$data = {
    temporals => [ 'date', 'year', 'null', undef, '2019-08-23', '2018-09-10 10:29:30']
};
```

## 在两个dsn对比的情况下，额外生成三个文件，分别是用于建表和生成数据的zz文件（ddl.sql），根据yy文件生成的所有的sql文件(total.sql)，以及在total.sql中两个dsn查询输出不同的sql以及不同之处（inconsis.sql）


```shell
perl gentest.pl \
   --dsn1=dbi:mysql:host=127.0.0.1:port=3306:user=root:database=test:password=123456 \
   --dsn2=dbi:mysql:host=127.0.0.1:port=4000:user=root:database=test \
   --gendata=conf/example.zz \
   --grammar=conf/example.yy
```

上面的目录将会在当前目录（可以通过`--targetdir`选项指定目录）生成`ddl.sql`，`total.sql`以及`inconsis.sql`三个文件。

`ddl.sql`是根据zz文件生成的建表和插入数据的sql语句，用于在恢复现场：

```sql
CREATE TABLE ....;
INSERT ...;
```

`total.sql`文件是所有根据yy文件随机生成的sql：

```sql
SELECT ...;
SELECT ...;
...
SELECT ...;
```

`inconsis.sql`文件存放的所有两个dsn输出不一致的sql并且把输出不同的地方写到sql下方的注释中去：

```sql
SELECT ...;
/*
# 14:33:25 --- /tmp//randgen8305-1558334005-server0.dump        2019-05-20 14:33:25.152868864 +0800
# 14:33:25 +++ /tmp//randgen8305-1558334005-server1.dump        2019-05-20 14:33:25.152868864 +0800
# 14:33:25 @@ -1,4 +1,4 @@
# 14:33:25 -0.0000
# 14:33:25 +0
# 14:33:25  0.0000
# 14:33:25  0.0000
# 14:33:25  1111.0000
# 14:33:25 Child process completed with error code 28.
*/
SELECT ...;
/*
# 14:33:26 --- /tmp//randgen8305-1558334006-server0.dump        2019-05-20 14:33:25.152868864 +0800
# 14:33:26 +++ /tmp//randgen8305-1558334006-server1.dump        2019-05-20 14:33:25.152868864 +0800
# 14:33:26 @@ -1,4 +1,4 @@
# ...
*/
```


## 根据算子，参数个数以及yy, zz文件模板自动生成yy以及zz文件，如果你愿意，也可以直接生成sql test文件

```shell
$ python template.py -h
usage: template.py [-h] [--tmpl TMPL] [--targetdir TARGETDIR]
                   [--gentest GENTEST]
                   operator param_num

generate .zz .yy file through template, given operator and parameter number

positional arguments:
  operator              operator to test
  param_num             the parameter number for the operator, if it can
                        accept any parameter number, you should assign
                        'unbound'

optional arguments:
  -h, --help            show this help message and exit
  --tmpl TMPL           template file to use. DEFAULT: tmpl
  --targetdir TARGETDIR
                        target directory for generated .zz .yy file. DEFAULT:
                        ./conf
  --gentest GENTEST     If set this flag, it will keep up generating sql test
                        file follow after .zz .yy generation
```

举个例子：

```shell
python template.py SUM 2
```

`SUM`是你想要测试的算子，而`2`是它所能接受的参数数目。结果文件位于`conf/SUM.yy`和`conf/SUM.zz`。

它将使用默认的模板文件（即`template/tmpl.yy`和`template/tmpl.zz`）。

 - `tmpl.zz`文件将会被直接拷贝成`SUM.zz`
 - 位于`tmpl.yy`中的模板变量将会被替换成`SUM( _field , _field )`，而成为`SUM.yy`


如果你要测试的算子可以接受任意数目的参数(比如`COALESCE`)，那么应该该将`param_num`参数指定为`unbound`：

```shell
python template.py COALESCE unbound
```

之后脚本生成的`COALESCE.yy`将会测试到2参数，3参数，5参数以及将全部字段作为参数的`COALESCE`算子

生成的`COALESCE.yy`看起来大概像这样：

```yacc
... operator ...

operator:
    COALESCE( _field , _field )
|   COALESCE( _field , _field , _field )
|   COALESCE( _field , _field , _field , _field , _field )
|   COALESCE( _fields )
```

如果你想要直接生成sql test文件，你可以增加参数`--gentest 1`，这样脚本就会在生成`.zz`和`.yy`文件之后，
紧接着用这两个文件生成sql文件:


```shell
python template.py --gentest 1 COALESCE unbound 
```

命令执行结束后，你会看到`test`目录下多出了一个`test/COALESCE.sql`文件。

你也可以通过`--tmpl`参数自定义模板文件，比如`--tmpl a`，就会选中`template/a.yy`和`template/a.zz`作为模板。