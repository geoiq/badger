#!/bin/sh
cd /
cd "$( dirname $0)"
java -jar jruby-complete.jar badger.rb --batch=data --user admin --password password --finder=http://finder.integra