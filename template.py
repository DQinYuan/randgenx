import argparse
from string import Template
import os
import shutil

def parse_args():
    parser = argparse.ArgumentParser(description="generate .zz .yy file through template, given operator and parameter number")
    parser.add_argument("--tmpl", dest="tmpl", help="template file to use. DEFAULT: tmpl", default="tmpl")
    parser.add_argument("--targetdir", dest="targetdir", help="target directory for generated .zz .yy file. DEFAULT: ./conf", default="./conf")
    parser.add_argument("operator", help="operator to test")
    parser.add_argument("param_num", help="the parameter number for the operator, if it can accept any parameter number, you should assign 'unbound'")
    args = parser.parse_args()
    return args

def operator_string(op, param_num):
    return "%s(%s)" % (op, ",".join(["_fields"] * param_num))

def read_tmplate(filepath):
    with open(filepath) as f:
        return f.read()

def write_content(filepath, content):
    with open(filepath, 'w') as f:
        f.write(content)


args = parse_args()

# 固定数量参数的算子
if args.param_num.isdigit():
    operator_str = operator_string(args.operator, int(args.param_num))
    template = read_tmplate("template/%s.yy" % args.tmpl)
    replaced = Template(template).substitute(operator=operator_str)
    write_content(os.path.join(args.targetdir, "%s.yy" % args.operator), replaced)
    shutil.copyfile("template/%s.zz" % args.tmpl, os.path.join(args.targetdir, "%s.zz" % args.operator))

