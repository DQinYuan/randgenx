
# Introduction
---

enhanced randgen tool with extra function. 

[randgen document](https://github.com/RQG/RQG-Documentation/wiki/RandomQueryGeneratorQuickStart)

# Change Proposal

## Gen sql without need to connect mysql server
 
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

## In Multi dsn comparasion, generate a total sql file and an inconsistent sql file (only support in two dsn compare)

```shell
perl gentest.pl \
   --dsn1=dbi:mysql:host=127.0.0.1:port=3306:user=root:database=test:password=123456 \
   --dsn2=dbi:mysql:host=127.0.0.1:port=4000:user=root:database=test \
   --gendata=conf/example.zz \
   --grammar=conf/example.yy
```

then it will generate `total.sql` and `inconsis.sql` in current directory. (You can assign directory by `--targetdir`)

`total.sql` file(all sql):

```sql
CREATE TABLE ....;
INSERT ...;
SELECT ...;
```

`inconsis.sql` file(gen data sql, inconsistent sql and inconsistent info):

```sql
CREATE TABLE ....;
INSERT ...;
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