#!/bin/bash
rake migrate

ruby dnsd.rb
