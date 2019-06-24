import argparse
from string import Template
import subprocess
import os
import shutil

def parse_args():
    parser = argparse.ArgumentParser(description="generate .zz .yy file through template, given operator and parameter number")
    parser.add_argument("--tmpl", dest="tmpl", help="template file to use. DEFAULT: tmpl", default="tmpl")
    parser.add_argument("--targetdir", dest="targetdir", help="target directory for generated .zz .yy file. DEFAULT: ./conf", default="./conf")
    parser.add_argument("--gentest", dest="gentest", type=bool, help="If set this flag, it will keep up generating sql test file follow after .zz .yy generation")
    parser.add_argument("operator", help="operator to test")
    parser.add_argument("param_num", help="the parameter number for the operator, if it can accept any parameter number, you should assign 'unbound'")
    args = parser.parse_args()
    return args

def operator_string(op, param_num):
    if param_num.isdigit():
        return "%s( %s )" % (op, " , ".join(["_field"] * int(param_num)))
    else:
        return "%s( _field_list )" % op

def read_tmplate(filepath):
    with open(filepath) as f:
        return f.read()

def write_content(filepath, content):
    with open(filepath, 'w') as f:
        f.write(content)


args = parse_args()

# 固定数量参数的算子
if args.param_num.isdigit():
    operator_str = operator_string(args.operator, args.param_num)
    template = read_tmplate("template/%s.yy" % args.tmpl)
    replaced = Template(template).substitute(operator=operator_str)
    write_content(os.path.join(args.targetdir, "%s.yy" % args.operator), replaced)
    shutil.copyfile("template/%s.zz" % args.tmpl, os.path.join(args.targetdir, "%s.zz" % args.operator))
# 不固定参数数量的算子
else:
    operator_strs = []
    for param_num in ('2', '3', '5', 'unbound'):
        operator_strs.append(operator_string(args.operator, param_num))
    operator_field = "operator:\n    " + "\n|   ".join(operator_strs)
    template = read_tmplate("template/%s.yy" % args.tmpl)
    replaced = Template(template).substitute(operator="operator")
    write_content(os.path.join(args.targetdir, "%s.yy" % args.operator), 
        replaced + "\n\n" + operator_field)
    shutil.copyfile("template/%s.zz" % args.tmpl, os.path.join(args.targetdir, "%s.zz" % args.operator))


if args.gentest:
    command = ["perl", "gentest.pl", 
        "--dsn=dummy:file:test/%s.sql" % args.operator,
        "--gendata=conf/%s.zz" % args.operator, 
        "--grammar=conf/%s.yy" % args.operator]
    errFilePath = "./stderr.txt"
    errFile = open(errFilePath, "w+")
    try:
        subprocess.check_call(command, stderr=errFile)
    except subprocess.CalledProcessError as e:
        errFile.close()
        errFile = open(errFilePath, "r")
        print("# ERROR:\n{}".format(errFile.read()))
        errFile.close()
            
    

