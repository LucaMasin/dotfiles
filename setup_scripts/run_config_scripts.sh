cd "$(dirname "$0")"

PYCMD=python3

for file in *.py
do
  $PYCMD "$file"
done