from jinja2 import Template
import sys


argv_dict = {}
inputfile = sys.argv[1]
argvs = sys.argv[2].split(" ")
outfile = sys.argv[3]

for argv in argvs:
    if len(argv.split("=")) == 2:
        _key = argv.split("=")[0]
        _value = argv.split("=")[1]
        argv_dict[_key] = _value


with open(inputfile) as file_:
    template = Template(file_.read())
templated_file = template.render(argv_dict)

with open(outfile, 'w') as out:
    out.write(templated_file)
