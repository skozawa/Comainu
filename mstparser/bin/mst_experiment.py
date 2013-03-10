#!/usr/bin/python

import os
import sys
import optparse

## Check that MSTPARSER_DIR environment variable is set and get it
global mstparser_dir
mstparser_dir = ''
if os.environ.has_key('MSTPARSER_DIR'):
    mstparser_dir = os.environ['MSTPARSER_DIR']
else:
    print "Please set the MSTPARSER_DIR environment variable to where you have the MSTParser installed."
    exit(1)


###########################################################################
#
# Run a single fold. This could actually be not a "fold" per se, but
# actually explicitly provided training and test files.
#
###########################################################################

def create_tag_train_file (source_file, formatted_file):

    output = file(formatted_file, "w")

    input = file(source_file)
    line = input.readline()
    while not(line == ""):
        words = line.strip().split("\t")
        line = input.readline()
        tags = line.strip().split("\t")

        # the splitting takes care of word+stem representations like biliyor+bil
        merged = [words[i].split("+")[0]+"_"+tags[i].replace("_", "+us+") \
                  for i in range(len(words))]

        output.write(" ".join(merged)+"\n")

        input.readline() # eat up labels
        input.readline() # eat up dependencies
        input.readline() # eat blank line
        line = input.readline() # read words of next sentence

    output.close()


def run_single_train_and_test(options, train_filename,
                              test_filename, output_filename, args):


    realtest_filename = test_filename
    # Tag the test sentences if requested
    if options.tag_source == "OTK_Tagger":
        print "  Tagging test sentences..."

        tag_train_filename = train_filename+".tagged"
        
        create_tag_train_file(train_filename, tag_train_filename)

        tagged_filename = test_filename+".tagged.tmp"
        tag_command = "python %s/bin/pos_tag.py -o %s %s %s %s" \
                      % (mstparser_dir,
                         options.output_dir,
                         tag_train_filename,
                         test_filename,
                         tagged_filename)
        
        #print >> argfile, tag_command
        if options.verbose:
            print tag_command
            os.system(tag_command)
            #os.system(tag_command+' |tee --append '+options.output_dir+'/tag.out 2>&1')
        else:
            os.system(tag_command+' &>/dev/null')
            #os.system(tag_command+' >> '+options.output_dir+'/tag.out 2>&1')


        tag_lines = []
        counter = 0
        for line in file(tagged_filename):
            if counter % 2 == 1:
                tag_lines.append(line)
            counter += 1

        realtest_filename = test_filename+".tagged"
        output = file(realtest_filename, "w")
        counter = 0
        for line in file(test_filename):
            if counter % 5 == 1:
                output.write(tag_lines[(counter-1)/5])
            else:
                output.write(line)
            counter += 1

        output.close()


    # Train the parser
    print "  Training and evaluating..."

    train_command = 'mst_parse.sh train train-file:%s model-name:%s/dep.model decode-type:%s test test-file:%s output-file:%s %s' % (train_filename, options.output_dir, options.decoder_type, realtest_filename, output_filename, " ".join(args[1:]))

    if options.verbose:
	print train_command
	os.system(train_command)
    else:
	os.system(train_command+' &>/dev/null')
    

###################### END FUNCTION DEFINITIONS ########################


## Get options

opt_parser = optparse.OptionParser()
opt_parser.add_option("-l", "--language", action="store", default='Unspecified',
		  help="use configurations specific to LANGUAGE",
		  metavar="LANGUAGE")
opt_parser.add_option("-e", "--eval_file", action="store", default='Generated',
		  help="Read evaluation sentences from FILE. Using this option means that cross-validation will not be used.",
		  metavar="FILE")
opt_parser.add_option("-d", "--decoder_type", action="store",
                      choices=['proj', 'non-proj'],
		      default="proj",
		      help="Use a projective or non-projective algorithm.E",
		      metavar="FILE")
opt_parser.add_option("-o", "--output_dir", action="store", default='output',
		  help="save parser output to DIR",
		  metavar="DIR")
opt_parser.add_option("-f", "--num_folds", action="store", default=10,
		  help="The number of folds to use in cross-validation (Default=10).",
		  metavar="NUM")
opt_parser.add_option("-v", "--verbose", action="store_true", default=False,
                      help="be verbose")

opt_parser.add_option("-t", "--tag_source", choices=['Gold','OTK_Tagger'],
                   default='Gold',
                   help="use tags from Gold standard or from a tagger (Gold (default), OTK_Tagger)",
                   metavar="SOURCE")

(options, args) = opt_parser.parse_args()

#Convert from FP to Int
options.num_folds = int(options.num_folds)

# Check that the requested output directory doesn't exist and isn't a
# file. If it's okay, create the directory.
output_dir = options.output_dir
if os.path.isdir(output_dir):
    os.system("rm -rf %s" % output_dir)
elif os.path.isfile(output_dir):
    raise OSError("A file with the same name as the desired dir, " \
		  "'%s', already exists." % output_dir)
os.makedirs(output_dir)


# This file accumulates the results across all folds.
model_output_filename = output_dir+"/model_out"
os.system('touch %s' % model_output_filename)

## Process files

train_filename = args[0]

# This file accumulates the gold dependencies across all folds.
gold_deps_filename = output_dir+"/gold.deps"

if options.eval_file == "Generated":

    num_folds = int(options.num_folds)
    
    print "Running a %d-fold evaluation on file %s" \
          % (num_folds, train_filename)
    print
    
    # Align parses with their corresponding sentences and assign a
    # partition id to them.
    
    train_file = file(train_filename)
    
    examples = []
    
    next_example = train_file.readline()
    
    counter = 0
    while next_example:
        partition = counter % num_folds
    
        elements = []
        while next_example and next_example != "\n":
            elements += next_example
            next_example = train_file.readline()
    
        examples.append((partition, elements))
    
        next_example = train_file.readline()
    
        counter += 1
    
    
    # Close the sentences file and delete it. (It was either copied or
    # generated, so it's okay.)
    train_file.close()
    
    # Train/test on each partion
    
    gold_deps = open(gold_deps_filename,"w")
    
    # Run each fold. The output from each fold is appended to gold.deps
    # and model.deps
    #for test_partition in range(1):
    for test_partition in range(num_folds):
    
        print "Fold",test_partition
    
        train_filename = output_dir+"/train"
        train_set = open(train_filename, "w")
    
        test_filename = output_dir+"/test"
        test_set = open(test_filename, "w")
    
        counter = 0
        for ex in examples:
            if ex[0] == test_partition:
                test_set.write("".join(ex[1])+"\n")
                gold_deps.write("".join(ex[1])+"\n")
            else:
                train_set.write("".join(ex[1])+"\n")
    
        counter += 1
    
        train_set.close()
        test_set.close()
    
        # Run the fold.
        output_filename = output_dir+"/output"
        run_single_train_and_test(options, train_filename, test_filename, output_filename, args)
    
        # Pile this fold's output onto the accumulating result file.
        os.system('cat %s >> %s' % (output_filename, model_output_filename))
    
        gold_deps.flush()
    
    gold_deps.close()

else:
    os.system('cp %s %s' %(options.eval_file, gold_deps_filename))
    
    run_single_train_and_test(options, train_filename, gold_deps_filename, model_output_filename, args)


################## EVALUATION ###################

print "Evaluating. If anything here dies, you can still look at the output files in the directory '%s'." % (output_dir)

# Get dependency results.

os.system("mst_score.sh %s %s" % (gold_deps_filename, model_output_filename))

