#!/usr/bin/python
import re
import optparse
import fileinput
import sys

###########################################################################
#
# Command-line options and usage
#
###########################################################################

usage = """%prog [OPTIONS] FILE ...

Convert from one dependency style to another.
Use -f FROM and -t TO to specify the input and output formats.
"""

parser = optparse.OptionParser(usage=usage)

parser.add_option("-r", "--rightward", action="store_true",
                   default=False,
                   help="""Create right-linking baseline.""")

parser.add_option("-d", "--default-relation", action="store",
		  default="Elaboration",
		  help="Pick default relation.",
		  metavar="RELATION")

def transform_meta_chars(string):
    return string.replace(",","+comma+")
def untransform_meta_chars(string):
    return string.replace("+comma+",",")

## Output dependencies for one sentence
def output_one_sentence(deps):
    accum = [[], [], [], [], []]
    for dep in deps:
        for num in xrange(len(dep)):
            accum[num].append(dep[num])
    accum = ["\t".join([str(x) for x in y]) for y in accum]
    print "\n".join(accum[1:])
    print


## Get options

(options, args) = parser.parse_args()

## Process file(s)

lines = fileinput.input(args)

deps = []

## Read input

sentence_info = []
for line in lines:
    line = line.strip()
    if not line:
	num_words = len(sentence_info[0])
	baseline_deps = range(num_words)
	if options.rightward:
	    baseline_deps.pop(0)
	    baseline_deps.pop(0)
	    baseline_deps += [num_words, 0]

	sentence_info[2] = [options.default_relation]*num_words
	sentence_info[3] = baseline_deps

	try:
	    for i in xrange(len(sentence_info[0])):
		deps.append([i+1]+[row[i] for row in sentence_info])
	except:
	    #print sentence_info
	    print "\n".join([len(x) for x in sentence_info])
	    sys.exit(0)

	#print deps
        output_one_sentence(deps)
        deps = []
        sentence_info = []
    else:
        sentence_info.append(line.split())

