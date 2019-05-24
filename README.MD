
# Introduction
---

enhanced randgen tool with extra function. It is stil developing

[randgen document](https://github.com/RQG/RQG-Documentation/wiki/RandomQueryGeneratorQuickStart)

# Change Proposal

## Gen sql without need to connect mysql server (Completed)
 
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

origin randgen do not support to assign datetime directly.

In randgenx, can assign as follow in .zz

```perl
$data = {
        ...
        temporals => ['date', 'year', 'null', undef, '2017-04-22 10:03:30' ]
}
```

## In Multi dsn comparasion, generate a total sql file and an inconsistent sql file

total sql file:

```sql
CREATE TABLE ....;
INSERT ...;
SELECT ...;
```

inconsistent sql file:

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

You can assign file to `--targetdir`







