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

        # int
        try:
            _value = int(_value)
            argv_dict[_key] = _value
            continue
        except ValueError:
            pass

        # float
        try:
            _value = float(_value)
            argv_dict[_key] = _value
        except ValueError:
            pass

        # str
        argv_dict[_key] = _value


with open(inputfile) as file_:
    template = Template(file_.read())
templated_file = template.render(argv_dict)

with open(outfile, 'w') as out:
    out.write(templated_file)
