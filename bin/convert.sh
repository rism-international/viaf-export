#!/bin/bash
cd ..
ruby marcxml --transform -i input/people.xml -c conf/person.yaml -o output/people.xml
ruby marcxml --transform -i input/institutions.xml -c conf/institution.yaml -o output/institutions.xml
