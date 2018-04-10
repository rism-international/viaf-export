#!/bin/bash
cd ..
ruby marcxml --transform -i input/people.xml -c conf/viaf.yaml -o output/people.xml
