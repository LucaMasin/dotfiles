cd "$(dirname "$0")"

if command -v python &> /dev/null
then
    PYCMD=python
else
    PYCMD=python3
fi

for file in *.py
do
  $PYCMD "$file"
done