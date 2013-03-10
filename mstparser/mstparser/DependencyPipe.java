package mstparser;

import mstparser.io.*;
import java.io.*;
import gnu.trove.*;
import java.util.*;

public class DependencyPipe {

    public Alphabet dataAlphabet;
	
    public Alphabet typeAlphabet;

    private DependencyReader depReader;
    private DependencyWriter depWriter;

    public String[] types;
    public int[] typesInt;
	
    public boolean labeled = false;
    private boolean isCONLL = true;

    private ParserOptions options;

    public DependencyPipe (ParserOptions options) throws IOException {
	this.options = options;

	if (!options.format.equals("CONLL"))
	    isCONLL = false;

	dataAlphabet = new Alphabet();
	typeAlphabet = new Alphabet();

	depReader = DependencyReader.createDependencyReader(options.format, options.discourseMode);
    }

    public void initInputFile (String file) throws IOException {
	labeled = depReader.startReading(file);
    }

    public void initOutputFile (String file) throws IOException {
	depWriter = 
	    DependencyWriter.createDependencyWriter(options.format, labeled);
	depWriter.startWriting(file);
    }

    public void outputInstance (DependencyInstance instance) throws IOException {
	depWriter.write(instance);
    }

    public void close () throws IOException {
	if (null != depWriter) {
	    depWriter.finishWriting();
	}
    }

    public String getType (int typeIndex) {
	return types[typeIndex];
    }

    protected final DependencyInstance nextInstance() throws IOException {
	DependencyInstance instance = depReader.getNext();
	if (instance == null || instance.forms == null) return null;

	instance.setFeatureVector(createFeatureVector(instance));
	
	String[] labs = instance.deprels;
	int[] heads = instance.heads;

	StringBuffer spans = new StringBuffer(heads.length*5);
	for(int i = 1; i < heads.length; i++) {
	    spans.append(heads[i]).append("|").append(i).append(":").append(typeAlphabet.lookupIndex(labs[i])).append(" ");
	}
	instance.actParseTree = spans.substring(0,spans.length()-1);
	
	return instance;
    }


    public int[] createInstances(String file,
				 File featFileName) throws IOException {

	createAlphabet(file);

	System.out.println("Num Features: " + dataAlphabet.size());

	labeled = depReader.startReading(file);

	TIntArrayList lengths = new TIntArrayList();

	ObjectOutputStream out = options.createForest
	    ? new ObjectOutputStream(new FileOutputStream(featFileName))
	    : null;
		
	DependencyInstance instance = depReader.getNext();
	int num1 = 0;

	System.out.println("Creating Feature Vector Instances: ");
	while(instance != null) {
	    System.out.print(num1 + " ");
	    
	    instance.setFeatureVector(createFeatureVector(instance));
			
	    String[] labs = instance.deprels;
	    int[] heads = instance.heads;

	    StringBuffer spans = new StringBuffer(heads.length*5);
	    for(int i = 1; i < heads.length; i++) {
		spans.append(heads[i]).append("|").append(i).append(":").append(typeAlphabet.lookupIndex(labs[i])).append(" ");
	    }
	    instance.actParseTree = spans.substring(0,spans.length()-1);

	    lengths.add(instance.length());
			
	    if(options.createForest)
		writeInstance(instance,out);
	    instance = null;
			
	    instance = depReader.getNext();

	    num1++;
	}

	System.out.println();

	closeAlphabets();
		
	if(options.createForest)
	    out.close();

	return lengths.toNativeArray();
		
    }

    private final void createAlphabet(String file) throws IOException {

	System.out.print("Creating Alphabet ... ");

	labeled = depReader.startReading(file);

	DependencyInstance instance = depReader.getNext();

	while(instance != null) {
	    
	    String[] labs = instance.deprels;
	    for(int i = 0; i < labs.length; i++)
		typeAlphabet.lookupIndex(labs[i]);
			
	    createFeatureVector(instance);
			
	    instance = depReader.getNext();
	}

	closeAlphabets();

	System.out.println("Done.");
    }
	
    public void closeAlphabets() {
	dataAlphabet.stopGrowth();
	typeAlphabet.stopGrowth();

	types = new String[typeAlphabet.size()];
	Object[] keys = typeAlphabet.toArray();
	for(int i = 0; i < keys.length; i++) {
	    int indx = typeAlphabet.lookupIndex(keys[i]);
	    types[indx] = (String)keys[i];
	}

	KBestParseForest.rootType = typeAlphabet.lookupIndex("<root-type>");
    }


    // add with default 1.0
    public final void add(String feat, FeatureVector fv) {
	int num = dataAlphabet.lookupIndex(feat);
	if(num >= 0)
	    fv.add(num, 1.0);
    }

    public final void add(String feat, double val, FeatureVector fv) {
	int num = dataAlphabet.lookupIndex(feat);
	if(num >= 0)
	    fv.add(num, val);
    }

	
    public FeatureVector createFeatureVector(DependencyInstance instance) {

	final int instanceLength = instance.length();

	String[] labs = instance.deprels;
	int[] heads = instance.heads;

	FeatureVector fv = new FeatureVector();
	for(int i = 0; i < instanceLength; i++) {
	    if(heads[i] == -1)
		continue;
	    int small = i < heads[i] ? i : heads[i];
	    int large = i > heads[i] ? i : heads[i];
	    boolean attR = i < heads[i] ? false : true;
	    addCoreFeatures(instance,small,large,attR,fv);
	    if(labeled) {
		addLabeledFeatures(instance,i,labs[i],attR,true,fv);
		addLabeledFeatures(instance,heads[i],labs[i],attR,false,fv);
	    }
	}

	addExtendedFeatures(instance, fv);

	return fv;
    }

    protected void addExtendedFeatures(DependencyInstance instance, 
				       FeatureVector fv) {}


    public void addCoreFeatures(DependencyInstance instance,
				int small,
				int large,
				boolean attR,
				FeatureVector fv) {

	String[] forms = instance.forms;
	String[] pos = instance.postags;
	String[] posA = instance.cpostags;

	String att = attR ? "RA" : "LA";

	int dist = Math.abs(large-small);
	String distBool = "0";
	if (dist > 10)
	    distBool = "10";
	else if (dist > 5)
	    distBool = "5";
	else
	    distBool = Integer.toString(dist-1);
		
	String attDist = "&"+att+"&"+distBool;

	addLinearFeatures("POS", pos, small, large, attDist, fv);
	addLinearFeatures("CPOS", posA, small, large, attDist, fv);
		

	//////////////////////////////////////////////////////////////////////
	
	int headIndex = small;
	int childIndex = large;
	if (!attR) {
	    headIndex = large;
	    childIndex = small;
	}

	addTwoObsFeatures("HC", forms[headIndex], pos[headIndex], 
			  forms[childIndex], pos[childIndex], attDist, fv);

	if (isCONLL) {

	    addTwoObsFeatures("HCA", forms[headIndex], posA[headIndex], 
	    		      forms[childIndex], posA[childIndex], attDist, fv);
	    
	    addTwoObsFeatures("HCC", instance.lemmas[headIndex], pos[headIndex], 
	    		      instance.lemmas[childIndex], pos[childIndex], 
	    		      attDist, fv);
	    
	    addTwoObsFeatures("HCD", instance.lemmas[headIndex], posA[headIndex], 
			      instance.lemmas[childIndex], posA[childIndex], 
			      attDist, fv);

	    if (options.discourseMode) {
		// Note: The features invoked here are designed for
		// discourse parsing (as opposed to sentential
		// parsing). It is conceivable that they could help for
		// sentential parsing, but current testing indicates that
		// they hurt sentential parsing performance.

		addDiscourseFeatures(instance, small, large,
				     headIndex, childIndex, 
				     attDist, fv);

	    } else {
		// Add in features from the feature lists. It assumes
		// the feature lists can have different lengths for
		// each item. For example, nouns might have a
		// different number of morphological features than
		// verbs.
	    
		for (int i=0; i<instance.feats[headIndex].length; i++) {
		    for (int j=0; j<instance.feats[childIndex].length; j++) {
			addTwoObsFeatures("FF"+i+"*"+j, 
					  instance.forms[headIndex], 
					  instance.feats[headIndex][i],
					  instance.forms[childIndex], 
					  instance.feats[childIndex][j], 
					  attDist, fv);
			
			addTwoObsFeatures("LF"+i+"*"+j, 
					  instance.lemmas[headIndex], 
					  instance.feats[headIndex][i],
					  instance.lemmas[childIndex], 
					  instance.feats[childIndex][j], 
					  attDist, fv);
		    }
		}
	    }

	} else {
	    // We are using the old MST format.  Pick up stem features
	    // the way they used to be done. This is kept for
	    // replicability of results for old versions.
	    int hL = forms[headIndex].length();
	    int cL = forms[childIndex].length();
	    if (hL > 5 || cL > 5) {
		addOldMSTStemFeatures(instance.lemmas[headIndex], 
				      pos[headIndex],
				      instance.lemmas[childIndex], 
				      pos[childIndex],
				      attDist, hL, cL, fv);
	    }
	}				       
		
    }
 
    private final void addLinearFeatures(String type, String[] obsVals, 
					 int first, int second,
					 String attachDistance,
					 FeatureVector fv) {
	
	String pLeft = first > 0 ? obsVals[first-1] : "STR";
	String pRight = second < obsVals.length-1 ? obsVals[second+1] : "END";
	String pLeftRight = first < second-1 ? obsVals[first+1] : "MID";
	String pRightLeft = second > first+1 ? obsVals[second-1] : "MID";

	// feature posR posMid posL
	StringBuilder featPos = 
	    new StringBuilder(type+"PC="+obsVals[first]+" "+obsVals[second]);

	for(int i = first+1; i < second; i++) {
	    String allPos = featPos.toString() + ' ' + obsVals[i];
	    add(allPos, fv);
	    add(allPos+attachDistance, fv);

	}

	addCorePosFeatures(type+"PT", pLeft, obsVals[first], pLeftRight, 
				pRightLeft, obsVals[second], pRight, attachDistance, fv);

    }


    private final void 
	addCorePosFeatures(String prefix,
			   String leftOf1, String one, String rightOf1, 
			   String leftOf2, String two, String rightOf2, 
			   String attachDistance, 
			   FeatureVector fv) {

	// feature posL-1 posL posR posR+1

	add(prefix+"="+leftOf1+" "+one+" "+two+"*"+attachDistance, fv);

	StringBuilder feat = 
	    new StringBuilder(prefix+"1="+leftOf1+" "+one+" "+two);
	add(feat.toString(), fv);
	feat.append(' ').append(rightOf2);
	add(feat.toString(), fv);
	feat.append('*').append(attachDistance);
	add(feat.toString(), fv);

	feat = new StringBuilder(prefix+"2="+leftOf1+" "+two+" "+rightOf2);
	add(feat.toString(), fv);
	feat.append('*').append(attachDistance);
	add(feat.toString(), fv);
	
	feat = new StringBuilder(prefix+"3="+leftOf1+" "+one+" "+rightOf2);
	add(feat.toString(), fv);
	feat.append('*').append(attachDistance);
	add(feat.toString(), fv);
	
	feat = new StringBuilder(prefix+"4="+one+" "+two+" "+rightOf2);
	add(feat.toString(), fv);
	feat.append('*').append(attachDistance);
	add(feat.toString(), fv);

	/////////////////////////////////////////////////////////////
	prefix = "A"+prefix;

	// feature posL posL+1 posR-1 posR
	add(prefix+"1="+one+" "+rightOf1+" "+leftOf2+"*"+attachDistance, fv);

	feat = new StringBuilder(prefix+"1="+one+" "+rightOf1+" "+leftOf2);
	add(feat.toString(), fv);
	feat.append(' ').append(two);
	add(feat.toString(), fv);
	feat.append('*').append(attachDistance);
	add(feat.toString(), fv);

	feat = new StringBuilder(prefix+"2="+one+" "+rightOf1+" "+two);
	add(feat.toString(), fv);
	feat.append('*').append(attachDistance);
	add(feat.toString(), fv);
	
	feat = new StringBuilder(prefix+"3="+one+" "+leftOf2+" "+two);
	add(feat.toString(), fv);
	feat.append('*').append(attachDistance);
	add(feat.toString(), fv);
	
	feat = new StringBuilder(prefix+"4="+rightOf1+" "+leftOf2+" "+two);
	add(feat.toString(), fv);
	feat.append('*').append(attachDistance);
	add(feat.toString(), fv);

	///////////////////////////////////////////////////////////////
	prefix = "B"+prefix;

	//// feature posL-1 posL posR-1 posR
	feat = new StringBuilder(prefix+"1="+leftOf1+" "+one+" "+leftOf2+" "+two);
	add(feat.toString(), fv);
	feat.append('*').append(attachDistance);
	add(feat.toString(), fv);

	//// feature posL posL+1 posR posR+1
	feat = new StringBuilder(prefix+"2="+one+" "+rightOf1+" "+two+" "+rightOf2);
	add(feat.toString(), fv);
	feat.append('*').append(attachDistance);
	add(feat.toString(), fv);

    }



    /**
     * Add features for two items, each with two observations, e.g. head,
     * head pos, child, and child pos.
     *
     * The use of StringBuilders is not yet as efficient as it could
     * be, but this is a start. (And it abstracts the logic so we can
     * add other features more easily based on other items and
     * observations.)
     **/
    private final void addTwoObsFeatures(String prefix, 
					 String item1F1, String item1F2, 
					 String item2F1, String item2F2, 
					 String attachDistance,
					 FeatureVector fv) {

	StringBuilder feat = new StringBuilder(prefix+"2FF1="+item1F1);
	add(feat.toString(), fv);
	feat.append('*').append(attachDistance);
	add(feat.toString(), fv);
	
	feat = new StringBuilder(prefix+"2FF1="+item1F1+" "+item1F2);
	add(feat.toString(), fv);
	feat.append('*').append(attachDistance);
	add(feat.toString(), fv);

	feat = new StringBuilder(prefix+"2FF1="+item1F1+" "+item1F2+" "+item2F2);
	add(feat.toString(), fv);
	feat.append('*').append(attachDistance);
	add(feat.toString(), fv);

	feat = new StringBuilder(prefix+"2FF1="+item1F1+" "+item1F2+" "+item2F2+" "+item2F1);
	add(feat.toString(), fv);
	feat.append('*').append(attachDistance);
	add(feat.toString(), fv);
	
	feat = new StringBuilder(prefix+"2FF2="+item1F1+" "+item2F1);
	add(feat.toString(), fv);
	feat.append('*').append(attachDistance);
	add(feat.toString(), fv);

	feat = new StringBuilder(prefix+"2FF3="+item1F1+" "+item2F2);
	add(feat.toString(), fv);
	feat.append('*').append(attachDistance);
	add(feat.toString(), fv);


	feat = new StringBuilder(prefix+"2FF4="+item1F2+" "+item2F1);
	add(feat.toString(), fv);
	feat.append('*').append(attachDistance);
	add(feat.toString(), fv);

	feat = new StringBuilder(prefix+"2FF4="+item1F2+" "+item2F1+" "+item2F2);
	add(feat.toString(), fv);
	feat.append('*').append(attachDistance);
	add(feat.toString(), fv);

	feat = new StringBuilder(prefix+"2FF5="+item1F2+" "+item2F2);
	add(feat.toString(), fv);
	feat.append('*').append(attachDistance);
	add(feat.toString(), fv);

	feat = new StringBuilder(prefix+"2FF6="+item2F1+" "+item2F2);
	add(feat.toString(), fv);
	feat.append('*').append(attachDistance);
	add(feat.toString(), fv);

	feat = new StringBuilder(prefix+"2FF7="+item1F2);
	add(feat.toString(), fv);
	feat.append('*').append(attachDistance);
	add(feat.toString(), fv);
	
	feat = new StringBuilder(prefix+"2FF8="+item2F1);
	add(feat.toString(), fv);
	feat.append('*').append(attachDistance);
	add(feat.toString(), fv);
	
	feat = new StringBuilder(prefix+"2FF9="+item2F2);
	add(feat.toString(), fv);
	feat.append('*').append(attachDistance);
	add(feat.toString(), fv);
	
    }

    public void addLabeledFeatures(DependencyInstance instance,
				   int word,
				   String type,
				   boolean attR,
				   boolean childFeatures,
				   FeatureVector fv) {
		
	if(!labeled) 
	    return;

	String[] forms = instance.forms;
	String[] pos = instance.postags;
	    
	String att = "";
	if(attR)
	    att = "RA";
	else
	    att = "LA";

	att+="&"+childFeatures;
		
	String w = forms[word];
	String wP = pos[word];

	String wPm1 = word > 0 ? pos[word-1] : "STR";
	String wPp1 = word < pos.length-1 ? pos[word+1] : "END";

	add("NTS1="+type+"&"+att,fv);
	add("ANTS1="+type,fv);
	for(int i = 0; i < 2; i++) {
	    String suff = i < 1 ? "&"+att : "";
	    suff = "&"+type+suff;

	    add("NTH="+w+" "+wP+suff,fv);
	    add("NTI="+wP+suff,fv);
	    add("NTIA="+wPm1+" "+wP+suff,fv);
	    add("NTIB="+wP+" "+wPp1+suff,fv);
	    add("NTIC="+wPm1+" "+wP+" "+wPp1+suff,fv);
	    add("NTJ="+w+suff,fv); //this

	}
    }


    private void addDiscourseFeatures (DependencyInstance instance, 
				       int small,
				       int large,
				       int headIndex,
				       int childIndex,
				       String attDist,
				       FeatureVector fv) {
    
	addLinearFeatures("FORM", instance.forms, small, large, attDist, fv);
	addLinearFeatures("LEMMA", instance.lemmas, small, large, attDist, fv);
	
	addTwoObsFeatures("HCB1", instance.forms[headIndex], 
			  instance.lemmas[headIndex],
			  instance.forms[childIndex], 
			  instance.lemmas[childIndex], 
			  attDist, fv);
	
	addTwoObsFeatures("HCB2", instance.forms[headIndex], 
			  instance.lemmas[headIndex],
			  instance.forms[childIndex], 
			  instance.postags[childIndex], 
			  attDist, fv);
	
	addTwoObsFeatures("HCB3", instance.forms[headIndex], 
			  instance.lemmas[headIndex],
			  instance.forms[childIndex], 
			  instance.cpostags[childIndex], 
			  attDist, fv);
	
	addTwoObsFeatures("HC2", instance.forms[headIndex], 
			  instance.postags[headIndex], 
			  instance.forms[childIndex], 
			  instance.cpostags[childIndex], attDist, fv);
	
	addTwoObsFeatures("HCC2", instance.lemmas[headIndex], 
			  instance.postags[headIndex], 
			  instance.lemmas[childIndex], 
			  instance.cpostags[childIndex], 
			  attDist, fv);
	
	
	//// Use this if your extra feature lists all have the same length.
	for (int i=0; i<instance.feats.length; i++) {
	
		addLinearFeatures("F"+i, instance.feats[i], small, large, attDist, fv);
	
		addTwoObsFeatures("FF"+i, 
				  instance.forms[headIndex], 
				  instance.feats[i][headIndex],
				  instance.forms[childIndex], 
				  instance.feats[i][childIndex],
				  attDist, fv);
		
		addTwoObsFeatures("LF"+i, 
				  instance.lemmas[headIndex], 
				  instance.feats[i][headIndex],
				  instance.lemmas[childIndex], 
				  instance.feats[i][childIndex],
				  attDist, fv);
		
		addTwoObsFeatures("PF"+i, 
				  instance.postags[headIndex], 
				  instance.feats[i][headIndex],
				  instance.postags[childIndex], 
				  instance.feats[i][childIndex],
				  attDist, fv);
		
		addTwoObsFeatures("CPF"+i, 
				  instance.cpostags[headIndex], 
				  instance.feats[i][headIndex],
				  instance.cpostags[childIndex], 
				  instance.feats[i][childIndex],
				  attDist, fv);
		
		
		for (int j=i+1; j<instance.feats.length; j++) {
		
		    addTwoObsFeatures("CPF"+i+"_"+j, 
				      instance.feats[i][headIndex],
				      instance.feats[j][headIndex],
				      instance.feats[i][childIndex],
				      instance.feats[j][childIndex],
				      attDist, fv);
		
		}
	
		for (int j=0; j<instance.feats.length; j++) {
	
		    addTwoObsFeatures("XFF"+i+"_"+j, 
				      instance.forms[headIndex],
				      instance.feats[i][headIndex],
				      instance.forms[childIndex],
				      instance.feats[j][childIndex],
				      attDist, fv);
	
		    addTwoObsFeatures("XLF"+i+"_"+j, 
				      instance.lemmas[headIndex],
				      instance.feats[i][headIndex],
				      instance.lemmas[childIndex],
				      instance.feats[j][childIndex],
				      attDist, fv);
	
		    addTwoObsFeatures("XPF"+i+"_"+j, 
				      instance.postags[headIndex],
				      instance.feats[i][headIndex],
				      instance.postags[childIndex],
				      instance.feats[j][childIndex],
				      attDist, fv);
	
	
		    addTwoObsFeatures("XCF"+i+"_"+j, 
				      instance.cpostags[headIndex],
				      instance.feats[i][headIndex],
				      instance.cpostags[childIndex],
				      instance.feats[j][childIndex],
				      attDist, fv);
	
	
		}
	
	}


	// Test out relational features
	if (options.useRelationalFeatures) {

	    //for (int rf_index=0; rf_index<2; rf_index++) {
	    for (int rf_index=0; 
		 rf_index<instance.relFeats.length; 
		 rf_index++) {
		
		String headToChild = 
		    "H2C"+rf_index+instance.relFeats[rf_index].getFeature(headIndex, childIndex);
	    
		addTwoObsFeatures("RFA1",
				  instance.forms[headIndex], 
				  instance.lemmas[headIndex],
				  instance.postags[childIndex],
				  headToChild,
				  attDist, fv);
		
		addTwoObsFeatures("RFA2",
				  instance.postags[headIndex], 
				  instance.cpostags[headIndex],
				  instance.forms[childIndex],
				  headToChild,
				  attDist, fv);
	    
	    	addTwoObsFeatures("RFA3",
				  instance.lemmas[headIndex], 
				  instance.postags[headIndex],
				  instance.forms[childIndex],
				  headToChild,
				  attDist, fv);
	    	
	    	addTwoObsFeatures("RFB1",
				  headToChild,
				  instance.postags[headIndex],
				  instance.forms[childIndex], 
				  instance.lemmas[childIndex],
				  attDist, fv);
	    	
	    	addTwoObsFeatures("RFB2",
				  headToChild,
				  instance.forms[headIndex],
				  instance.postags[childIndex], 
				  instance.cpostags[childIndex],
				  attDist, fv);
	    	
	    	addTwoObsFeatures("RFB3",
				  headToChild,
				  instance.forms[headIndex],
				  instance.lemmas[childIndex], 
				  instance.postags[childIndex],
				  attDist, fv);
		
	    }
	}
    }


    public void fillFeatureVectors(DependencyInstance instance,
				   FeatureVector[][][] fvs,
				   double[][][] probs,
				   FeatureVector[][][][] nt_fvs,
				   double[][][][] nt_probs, Parameters params) {

	final int instanceLength = instance.length();

	// Get production crap.		
	for(int w1 = 0; w1 < instanceLength; w1++) {
	    for(int w2 = w1+1; w2 < instanceLength; w2++) {
		for(int ph = 0; ph < 2; ph++) {
		    boolean attR = ph == 0 ? true : false;
		    
		    int childInt = attR ? w2 : w1;
		    int parInt = attR ? w1 : w2;
		    
		    FeatureVector prodFV = new FeatureVector();
		    addCoreFeatures(instance,w1,w2,attR, prodFV)
;
		    double prodProb = params.getScore(prodFV);
		    fvs[w1][w2][ph] = prodFV;
		    probs[w1][w2][ph] = prodProb;
		}
	    }
	}

	if(labeled) {
	    for(int w1 = 0; w1 < instanceLength; w1++) {
		for(int t = 0; t < types.length; t++) {
		    String type = types[t];
		    for(int ph = 0; ph < 2; ph++) {

			boolean attR = ph == 0 ? true : false;
			for(int ch = 0; ch < 2; ch++) {

			    boolean child = ch == 0 ? true : false;

			    FeatureVector prodFV = new FeatureVector();
			    addLabeledFeatures(instance,w1,
					       type,attR,child, prodFV);
			    
			    double nt_prob = params.getScore(prodFV);
			    nt_fvs[w1][t][ph][ch] = prodFV;
			    nt_probs[w1][t][ph][ch] = nt_prob;
			    
			}
		    }
		}
	    }
	}		
    }


    /**
     * Write an instance to an output stream for later reading.
     *
     **/
    protected void writeInstance(DependencyInstance instance, ObjectOutputStream out) {

	int instanceLength = instance.length();

	try {

	    for(int w1 = 0; w1 < instanceLength; w1++) {
		for(int w2 = w1+1; w2 < instanceLength; w2++) {
		    for(int ph = 0; ph < 2; ph++) {
			boolean attR = ph == 0 ? true : false;
			FeatureVector prodFV = new FeatureVector();
			addCoreFeatures(instance,w1,w2,attR,prodFV);
			out.writeObject(prodFV.keys());
		    }
		}
	    }
	    out.writeInt(-3);

	    if(labeled) {
		for(int w1 = 0; w1 < instanceLength; w1++) {		    
		    for(int t = 0; t < types.length; t++) {
			String type = types[t];			
			for(int ph = 0; ph < 2; ph++) {
			    boolean attR = ph == 0 ? true : false;
			    for(int ch = 0; ch < 2; ch++) {
				boolean child = ch == 0 ? true : false;
				FeatureVector prodFV = new FeatureVector();
				addLabeledFeatures(instance,w1,
						   type, attR,child,prodFV);
				out.writeObject(prodFV.keys());
			    }
			}
		    }
		}
		out.writeInt(-3);
	    }

	    writeExtendedFeatures(instance, out);

	    out.writeObject(instance.fv.keys());
	    out.writeInt(-4);

	    out.writeObject(instance);
	    out.writeInt(-1);

	    out.reset();

	} catch (IOException e) {}
		
    }
	

    /**
     * Override this method if you have extra features that need to be
     * written to disk. For the basic DependencyPipe, nothing happens.
     *
     */
    protected void writeExtendedFeatures (DependencyInstance instance, ObjectOutputStream out) 
	throws IOException {}


    /**
     * Read an instance from an input stream.
     *
     **/
    public DependencyInstance readInstance(ObjectInputStream in,
					   int length,
					   FeatureVector[][][] fvs,
					   double[][][] probs,
					   FeatureVector[][][][] nt_fvs,
					   double[][][][] nt_probs,
					   Parameters params) throws IOException {

	try {

	    // Get production crap.		
	    for(int w1 = 0; w1 < length; w1++) {
		for(int w2 = w1+1; w2 < length; w2++) {
		    for(int ph = 0; ph < 2; ph++) {
			FeatureVector prodFV = new FeatureVector((int[])in.readObject());
			double prodProb = params.getScore(prodFV);
			fvs[w1][w2][ph] = prodFV;
			probs[w1][w2][ph] = prodProb;
		    }
		}
	    }
	    int last = in.readInt();
	    if(last != -3) { System.out.println("Error reading file."); System.exit(0); }
	    
	    if(labeled) {
		for(int w1 = 0; w1 < length; w1++) {
		    for(int t = 0; t < types.length; t++) {
			String type = types[t];
			
			for(int ph = 0; ph < 2; ph++) {						
			    for(int ch = 0; ch < 2; ch++) {
				FeatureVector prodFV = new FeatureVector((int[])in.readObject());
				double nt_prob = params.getScore(prodFV);
				nt_fvs[w1][t][ph][ch] = prodFV;
				nt_probs[w1][t][ph][ch] = nt_prob;
			    }
			}
		    }
		}
		last = in.readInt();
		if(last != -3) { System.out.println("Error reading file."); System.exit(0); }
	    }

	    FeatureVector nfv = new FeatureVector((int[])in.readObject());
	    last = in.readInt();
	    if(last != -4) { System.out.println("Error reading file."); System.exit(0); }

	    DependencyInstance marshalledDI;
	    marshalledDI = (DependencyInstance)in.readObject();
	    marshalledDI.setFeatureVector(nfv);	

	    last = in.readInt();
	    if(last != -1) { System.out.println("Error reading file."); System.exit(0); }

	    return marshalledDI;

	} catch(ClassNotFoundException e) { 
	    System.out.println("Error reading file."); System.exit(0); 
	} 

	// this won't happen, but it takes care of compilation complaints
	return null;
    }
		
    /**
     * Get features for stems the old way. The only way this differs
     * from calling addTwoObsFeatures() is that it checks the
     * lengths of the full lexical items are greater than 5 before
     * adding features.
     *
     */
    private final void
	addOldMSTStemFeatures(String hLemma, String headP, 
			      String cLemma, String childP, String attDist, 
			      int hL, int cL, FeatureVector fv) {

	String all = hLemma + " " + headP + " " + cLemma + " " + childP;
	String hPos = headP + " " + cLemma + " " + childP;
	String cPos = hLemma + " " + headP + " " + childP;
	String hP = headP + " " + cLemma;
	String cP = hLemma + " " + childP;
	String oPos = headP + " " + childP;
	String oLex = hLemma + " " + cLemma;
	
	add("SA="+all+attDist,fv); //this
	add("SF="+oLex+attDist,fv); //this
	add("SAA="+all,fv); //this
	add("SFF="+oLex,fv); //this
	
	if(cL > 5) {
	    add("SB="+hPos+attDist,fv);
	    add("SD="+hP+attDist,fv);
	    add("SK="+cLemma+" "+childP+attDist,fv);
	    add("SM="+cLemma+attDist,fv); //this
	    add("SBB="+hPos,fv);
	    add("SDD="+hP,fv);
	    add("SKK="+cLemma+" "+childP,fv);
	    add("SMM="+cLemma,fv); //this
	}
	if(hL > 5) {
	    add("SC="+cPos+attDist,fv);
	    add("SE="+cP+attDist,fv);
	    add("SH="+hLemma+" "+headP+attDist,fv);
	    add("SJ="+hLemma+attDist,fv); //this
	    
	    add("SCC="+cPos,fv);
	    add("SEE="+cP,fv);
	    add("SHH="+hLemma+" "+headP,fv);
	    add("SJJ="+hLemma,fv); //this
	}

    }
		
}
