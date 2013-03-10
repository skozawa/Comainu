#!/usr/bin/python

import os
import sys
import optparse

import tagging_util

## Check that DBPARSER_DIR environment variable is set and get it
dbparser_dir = ''
if os.environ.has_key('DBPARSER_DIR'):
    dbparser_dir = os.environ['DBPARSER_DIR']
else:
    print "Please set the DBPARSER_DIR environment variable to where you have Dan Bikel's parser installed."
    exit(1)

## Check that OPENNLP_DIR environment variable is set and get it
otk_dir = ''
if os.environ.has_key('OPENNLP_DIR'):
    otk_dir = os.environ['OPENNLP_DIR']
else:
    print "Please set the OPENNLP_DIR environment variable to where you have the OpenNLP Toolkit installed."
    exit(1)


## Get options

opt_parser = optparse.OptionParser()
opt_parser.add_option("-o", "--output-dir", action="store", default='output',
		  help="save tagger output to DIR",
		  metavar="DIR")
opt_parser.add_option("-v", "--verbose", action="store_true", default=False,
                      help="be verbose")

(options, args) = opt_parser.parse_args()

verbose = options.verbose

output_dir = options.output_dir
if os.path.isfile(output_dir):
    raise OSError("A file with the same name as the desired dir, " \
		  "'%s', already exists." % output_dir)
elif not(os.path.isdir(output_dir)):
    os.makedirs(output_dir)


## Process files

adwait_tagged_filename = args[0]
test_sentences = file(args[1])
output_file = open(args[2], "w")

# Use the gold trees to produce tagged sentences in Adwait's format
# with underscore separator.
#
# Note: any underscores in the tags themselves will be converted to
# +us+ metacharacters. These get unconverted at the end.
#os.system("python %s/python/parse_to_sentence.py -t -f Adwait -s -d %s > %s"
#          % (dbparser_dir, tree_filename, adwait_tagged_filename))

model_filename = output_dir+"/model.bin.gz"


# Make a tag dictionary
tag_dictionary_filename = output_dir+"/tag_dict"
os.system("python %s/python/create_tag_dictionary.py -s _ %s > %s"
          % (dbparser_dir, adwait_tagged_filename, tag_dictionary_filename))

# Train the tagger
os.system("%s/bin/otk_train_tagger.sh -dict %s %s %s &> /dev/null"
          % (otk_dir, tag_dictionary_filename, adwait_tagged_filename, model_filename))

sentences_to_tag_filename = output_dir+"/to_tag.txt"

# Strip off the parens that are used in the input to parser
to_tag_file = open(sentences_to_tag_filename, "w")
counter = 0
for sentence in test_sentences:
    if counter % 5 == 0:
        clean = "\t".join([x.split("+")[0] for x in sentence.strip().split("\t")])
        to_tag_file.write(clean+"\n")
    counter += 1
to_tag_file.close()

tagged_filename = output_dir+"/tagged.txt"

# Run the tagger
os.system("%s/bin/otk_run_tagger.sh -dict %s -tag_dict %s %s %s > %s"
          % (otk_dir, tag_dictionary_filename, tag_dictionary_filename,
             sentences_to_tag_filename, model_filename, tagged_filename))


# Convert tagger output to MST format. Unconvert the +us+
# metachars back to underscores too (using tagging_util.de_metatize()).
for tagged_sent in file(tagged_filename):
    words = []
    tags = []
    for word_tag in tagged_sent.split():
        (word,tag) = tagging_util.split_item(word_tag, "_")
        words.append(word)
        tags.append(tagging_util.de_metatize(tag,"_","+us+"))
    output_file.write("\t".join(words)+"\n")
    output_file.write("\t".join(tags)+"\n")

output_file.close()
