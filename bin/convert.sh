#!/bin/bash
cd ..
ruby marcxml --transform -i input/sources/input.xml -c conf/iccu.yaml -o output/output.xml
