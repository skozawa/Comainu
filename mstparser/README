-------------------------
MSTParser version 0.5.0
-------------------------

This is the main README. See ALT_README for some extra utilities and
an alternative build process to the one described in this README. The
package has been modified by Jason Baldridge -- this version should
produce the same results as Ryan McDonald's previous releases, but it
has been made more flexible and configurable in the input formats it
accepts (both MST and CoNLL) and in the way features are declared (see
the DependencyPipe class).

-------------------------


The following package contains a java implementation of the dependency
parsers described in:

Non-Projective Dependency Parsing using Spanning Tree Algorithms
R. McDonald, F. Pereira, K. Ribarov and J. Hajic
HLT-EMNLP, 2005

Online Large-Margin Training of Dependency Parsers
R. McDonald, K. Crammer and F. Pereira
ACL, 2005

Online Learning of Approximate Dependency Parsing Algorithms
R. McDonald and F. Pereira
EACL, 2006

In addition, the parsers in this package can also learn and produce typed
dependency trees (i.e. trees with edge labels).

The parser should work with Java 1.4 and 1.5

If there are any problems running the parser then email: ryantm@cis.upenn.edu
I will only respond to questions not answered in this README.


----------------
Contents
----------------

1. Compiling

2. Example of usage

3. Running the parser
   a. Input data format
   b. Training a parser
   c. Running a trained model on new data
   d. Evaluating output

4. Memory/Disk space and performance issues

5. Reproducing results in HLT-EMNLP and ACL papers


----------------
1. Compiling
----------------

To compile the code, first unzip/tar the downloaded file:

> gunzip mstparser.tar.gz
> tar -xvf mstparser.tar
> cd MSTParser

Next, run the following command

> javac -classpath ".:lib/trove.jar" mstparser/DependencyParser.java

This will compile the package.


---------------------
2. Example Usage
---------------------

In the directory data/ there are examples of training and testing data. Data
format is described in the next section.

train.ulab/test.ulab
- training and testing data with unlabeled trees

train.lab/test.lab
- training and testing data with labeled trees

To run an unlabeled parser type:

> java -classpath ".:lib/trove.jar" -Xmx1800m mstparser.DependencyParser \
  train train-file:data/train.ulab model-name:dep.model \
  test test-file:data/test.ulab output-file:out.txt \
  eval gold-file:data/test.ulab format:MST
  
This will train a parser on the training data, run it on the testing data and
evaluate the output against the gold standard. The results from running the
parser are in the file out.txt and the trained model in dep.model.

To train an labeled parser run the same command but use the labeled training
and testing files.


-------------------------
3. Running the Parser
-------------------------

-------------------------
3a. Input data format
-------------------------

**************************** NOTE **********************************
The parser now uses CONLL format as a default. Note the inclusion of
the format:MST option in the instructions below, which differ from the
instructions in previous versions (v0.2 and before). If you wish to
run the parser on CONLL formatted files, use format:CONLL or just
don't include the format option.
********************************************************************

Example data sets are given in the data/ directory.

Each sentence in the data is represented by 3 or 4 lines and sentences are
space separated. The general format is:

w1    w2    ...    wn
p1    p2    ...    pn
l1    l2    ...    ln
d1    d2    ...    d2

....


Where,
- w1 ... wn are the n words of the sentence (tab deliminated)
- p1 ... pn are the POS tags for each word
- l1 ... ln are the labels of the incoming edge to each word
- d1 ... dn are integers representing the postition of each words parent

For example, the sentence "John hit the ball" would be:

John	hit	the	ball
N	V	D	N
SBJ	ROOT	MOD	OBJ
2	0	4	2

Note that hit's parent is indexed by 0 since it is the root.

If you wish to only train or test an unlabeled parser, then simply leave out
the third line for each sentence, e.g.,

John	hit	the	ball
N	V	D	N
2	0	4	2

The parser will automatically detect that it should produce unlabeled trees.

Note that this format is the same for training AND for running the parser on
new data. Of course, you may not always know the gold standard. In this case,
just substitute lines 3 (the edge labels) and lines 4 (the parent indexes) with
dummy values. The parser just ignores these values and produces its own.


----------------------------
3b. Training the parser
----------------------------

If you have a set of labeled data, first place it in the format described
above.

If your training data is in a file train.txt, you can then run the command:

> java -classpath ".:lib/trove.jar" -Xmx1800m mstparser.DependencyParser \
  train train-file:train.txt format:MST

This will train a parser with all the default properties. Additonal
properties can be described with the following flags:

train
- if present then parser will train a new model

train-file:file.txt
- use data in file.txt to train the parser

model-name:model.name
- store trained model in file called model.name

iters:numIters
- Run training algorithm for numIters epochs, default is 10

decode-type:type
- type is either "proj" or "non-proj", e.g. decode-type:proj
- Default is "proj"
- "proj" use the projective parsing algorithm during training
  - i.e. The Eisner algorithm
- "non-proj" use the non-projective parsing algorithm during training
  - i.e. The Chu-Liu-Edmonds algorithm

training-k:K
- Specifies the k-best parse set size to create constraints during training
- Default is 1
- For non-projective parsing algorithm, k-best decoding is approximate

loss-type:type
- type is either "punc" or "nopunc", e.g. loss-type:punc
- Default is "punc"
- "punc" include punctuation in hamming loss calculation
- "nopunc" do not include punctuation in hamming loss calculation

create-forest:cf
- cf is either "true" or "false"
- Default is "true"
- If create-forest is false, it will not create the training parse forest (see
  section 4). It assumes it has been created.
- This flag is useful if you are training many models on the same data and
  features but using different parameters (e.g. training iters, decoding type).

order:ord
- ord is either 1 or 2
- Default is 1
- Specifies the order/scope of features. 1 only has features over single edges
  and 2 has features over pairs of adjacent edges in the tree.

format:FORMAT
- FORMAT is either MST or CONLL
- Default is CONLL
- Specifies whether the input/output format. MST is the format used by
  MSTParser until version 0.2.1. CONLL is the format used in the
  CONLL-X shared task (see http://nextens.uvt.nl/~conll/).

------------------------------------------------
3c. Running a trained model on new data
------------------------------------------------

This section assumes you have trained a model and it is stored in dep.model.

First, format your data properly (section 3a).

It should be noted that the parser assumes both words and POS tags. To
generate POS tags for your data I suggest using the Ratniparkhi POS tagger
or another tagger of your choice.

The parser also assumes that the edge label and parent index lines are
in the input. However, these can just be artificially inserted (e.g. with lines
of "LAB ... LAB" and "0 ... 0") since the parser will produce these lines
as output.

If the data is in a file called test.txt, run the command:

> java -classpath ".:lib/trove.jar" -Xmx1800m mstparser.DependencyParser \
  test model-name:dep.model test-file:test.txt output-file:out.txt format:MST

This will create an output file "out.txt" with the predictions of the parser.
Other properties can be defined with the following flags:

test
- If included a trained parser will be run on the testing data

test-file:file.txt
- The file containing the data to run the parser on

model-name:model.name
- The name of the stored model to be used

output-file:out.txt
- The result of running the parser on the new data

decode-type:type
- See section 3b.

order:ord
- See section 3b. THIS NEEDS TO HAVE THE SAME VALUE OF THE TRAINED MODEL!!

format:FORMAT
- See section 3b.

Note that if you train a labeled model, you should only run it expecting
labeled output (e.g. the test data should have 4 lines per sentence).
And if you train an unlabeled model, you should only run it expecting
unlabeled output (e.g. the test data should have 3 lines per sentence).


------------------------
3d. Evaluating Output
------------------------

This section describes a simple class for evaluating the output of
the parser against a gold standard.

Assume you have a gold standard, say test.txt and the output of the parser
say out.txt, then run the following command:

> java -classpath ".:lib/trove.jar" -Xmx1800m mstparser.DependencyParser \
  eval gold-file:test.txt output-file:out.txt MST

This will return both labeled and unlabeled accuracy (if the data sets contain
labeled trees) as well as complete sentence accuracy, again labeled and
unlabeled.

If your data is in CONLL format instead of MST format (pre-v0.2.1),
then replace MST by CONLL in the above command, or just leave it off
-- it defaults to CONLL.

We should note that currently this evaluation script includes all punctuation.
In future releases we will modify this class to allow for the evaluation to
ingnore punctuation, which is standard for English (Yamada and Matsumoto 03).


---------------------------------------------
4. Memory/Disk space and performance issues
---------------------------------------------

This parser is memory and disk space intensive.

MEMORY ISSUES

Remember to always run java with the flag -Xmx1800m to use all available
memory for the heap. For 64-bit machines use an even larger value, say
-Xmx8000m.

Training a model on the WSJ can be done easily on a 32-bit machine.
It should also be possible to train a model on the entire Prague Dependency
Treebank on a 32-bit machine (I have done it), but I make no guarantees.

DISK ISSUES

To make training quicker we store the entire parse forest on disk, ala
Clark and Curran 04. This can be very large, up to and over 20GB!! Be aware
of this fact.

If you train using a file called train.txt, the forest will be stored in
a file called train.txt.forest. If disk space is an issue you can remove this
file immediately after training (it is not need to run the parser on new data).

However, sometimes it is good to keep this file around. Particularly, if you
are retraining a model on the same data and feature space but want to try
different training settings. By using the create-forest:false flag, you
can avoid having to recreate this file (which can take some time).

PERFORMANCE ISSUES

Once a model has been trained, running the model on new data is pretty quick.
However, as with all discriminative trained parsers, it does take some time
to train a parser. On a two year old 32-bit machine is will take 10-15 hours
to train a model on the entire Penn Treebank and around 24-30 hours to train
a model on the Prague Dependency Treebank. Newer machines or 64-bit machines
are of course much quicker.


-------------------------------------------------------
5. Reproducing results in HLT-EMNLP and ACL papers
-------------------------------------------------------

To reproduce the English results in McDonald et al. ACL 2005,

> java -classpath ".:lib/trove.jar" -Xmx1800m mstparser.DependencyParser \
  train train-file:train.wsj model-name:eng.wsj.model \
  training-k:5 loss-type:nopunc decode-type:proj \
  test test-file:test.wsj output-file:out.txt \
  eval gold-file:test.wsj format:MST

This assumes that train.wsj is section 02-21 of the Penntreebank formatted
above and dependencies extracted using the head-rules of Yamada and Matsumoto.
See Joakim Nivre's tool set at:
  http://w3.msi.vxu.se/~nivre/research/Penn2Malt.html
for a tool set to convert the WSJ to dependencies using the Yamada and
Matsumoto head rules.

test.wsj is section 23 of the WSJ converted as above. Furthermore, POS tags are
supplied using Adwait Ratniparkhi's MXPOST tool-kit trained on sections 02-21.
This can be found at:
http://www.cogsci.ed.ac.uk/~jamesc/taggers/MXPOST.html

Note that the evaluation will be slightly off from the results reported. This
is because the evaluation scripts include punctuation. If you modify the
evaluation script to discount punctuation, results will align.


To reproduce the Czech results in McDonald et al. HLT-EMNLP 2005,

> java -classpath ".:lib/trove.jar" -Xmx1800m mstparser.DependencyParser \
  train train-file:train.pdt model-name:czech.pdt.model \
  training-k:1 loss-type:punc decode-type:non-proj \
  test test-file:test.pdt output-file:out.txt \
  eval gold-file:test.pdt format:MST

This assumes train.pdt and test.pdt are the training and testing sections
of the Prague Dependency Treebank v1.0 formatted above. We use the
automatically assigned POS tags that have been reduced (see paper).
