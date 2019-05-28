
# Introduction
---

enhanced randgen tool with extra function. 

[randgen document](https://github.com/RQG/RQG-Documentation/wiki/RandomQueryGeneratorQuickStart)

# Change Proposal

## Gen sql of MySQL without need to connect mysql server
 
You must connect at least one mysql server to gen test in origin randgen.

I enhanced dummy mode, so you can gen sql directly without need to connect mysql server as follow:

```shell
perl gentest.pl \
   --dsn=dummy:file:example.sql \
   --gendata=conf/example.zz \
   --grammar=conf/example.yy
```

then all sql will be writed to example.sql

When use this feature, `--threads` will be forced to 1 no matter the num you set.

`--queries` is the accurate num of sqls generated according `--grammar`

## Assign datetime directly in .zz file

By researshing randgen source code, I find it support it originally, as follow:

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

## In Multi dsn comparasion, it will extra generate three file, include a ddl sql file, a total grammar sql file and an inconsistent grammar sql file (only support in two dsn compare)

```shell
perl gentest.pl \
   --dsn1=dbi:mysql:host=127.0.0.1:port=3306:user=root:database=test:password=123456 \
   --dsn2=dbi:mysql:host=127.0.0.1:port=4000:user=root:database=test \
   --gendata=conf/example.zz \
   --grammar=conf/example.yy
```

then it will generate `ddl.sql`, `total.sql` and `inconsis.sql` in current directory. (You can customize directory by `--targetdir`)

formats of the three files as follows:

`test/ddl.sql` file (sql of data initialization):

```sql
CREATE TABLE ....;
INSERT ...;
```

`test/total.sql` file(all random sql defined by grammar file):

```sql
SELECT ...;
SELECT ...;
...
SELECT ...;
```

`test/inconsis.sql` file(inconsistent sql and inconsistent info for the 2 dsns):

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

You can see that the inconsistent info will be writed in comment of sql file.

## Generate a pair of yy, zz for an operator through a use-defined template, it can also directly generate sql test file if you want

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


for example:

```shell
python template.py SUM 2
```

`SUM` is the operator you want to test and `2` is the parameter it can accept.Result file is 'conf/SUM.yy' and 'conf/SUM.zz'.

It will use default template file('template/tmpl.yy' and 'template/tmpl.zz').  

 - 'tmpl.zz' will be dirtectly copied to 'SUM.zz'; 
 - Template variable `$operator` in 'tmpl.yy' will be replaced with `SUM( _field , _field )` 

It you want to test a operator can accept any number of parameters(such as `COALESCE`)， you should write as follow:

```shell
python template.py COALESCE unbound
```

Then it will generate a test with 2 parameter COALESCE, 3 parameter COALESCE, 5 parameter COALESCE and COALESCE having all fields as parameters.

The result `COALESCE.yy` perhaps like this:

```yacc
... operator ...

operator:
    COALESCE( _field , _field )
|   COALESCE( _field , _field , _field )
|   COALESCE( _field , _field , _field , _field , _field )
|   COALESCE( _fields )
```

If you want to generate sql test file directly, you can add parameter `--gentest 1`. Then it will use the pair of .zz .yy file to 
generate sql file just after generation of zz yy, for example:

```shell
python template.py --gentest 1 COALESCE unbound 
```

After execution, you will see the result in 'test/COALESCE.sql'.

You can alse customize template by `--tmpl` parameter.

