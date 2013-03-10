package mstparser;

import java.io.*;
import gnu.trove.*;
import java.util.*;
import mstparser.io.*;

public class DependencyPipe2O extends DependencyPipe {

    public DependencyPipe2O(ParserOptions options) throws IOException {
	super(options);
    }

			
    protected void addExtendedFeatures(DependencyInstance instance,
				       FeatureVector fv) {
	    
	final int instanceLength = instance.length();
	int[] heads = instance.heads;

	// find all trip features
	for(int i = 0; i < instanceLength; i++) {
	    if(heads[i] == -1 && i != 0) continue;
	    // right children
	    int prev = i;
	    for(int j = i+1; j < instanceLength; j++) {
		if(heads[j] == i) {
		    addTripFeatures(instance,i,prev,j,fv);
		    addSiblingFeatures(instance,prev,j,prev==i,fv);
		    prev = j;
		}
	    }
	    prev = i;
	    for(int j = i-1; j >= 0; j--) {
		if(heads[j] == i) {
		    addTripFeatures(instance,i,prev,j,fv);
		    addSiblingFeatures(instance,prev,j,prev==i,fv);
		    prev = j;
		}
	    }
	}
    }

    public void fillFeatureVectors(DependencyInstance instance,
				   FeatureVector[][][] fvs,
				   double[][][] probs,
				   FeatureVector[][][] fvs_trips,
				   double[][][] probs_trips,
				   FeatureVector[][][] fvs_sibs,
				   double[][][] probs_sibs,
				   FeatureVector[][][][] nt_fvs,
				   double[][][][] nt_probs, Parameters params) {

	fillFeatureVectors(instance, fvs, probs, nt_fvs, nt_probs, params);

	final int instanceLength = instance.length();

	for(int w1 = 0; w1 < instanceLength; w1++) {
	    for(int w2 = w1; w2 < instanceLength; w2++) {
		for(int w3 = w2+1; w3 < instanceLength; w3++) {
		    FeatureVector prodFV = new FeatureVector();
		    addTripFeatures(instance,w1,w2,w3,prodFV);
		    double prodProb = params.getScore(prodFV);
		    fvs_trips[w1][w2][w3] = prodFV;
		    probs_trips[w1][w2][w3] = prodProb;
		}
	    }
	    for(int w2 = w1; w2 >= 0; w2--) {
		for(int w3 = w2-1; w3 >= 0; w3--) {
		    FeatureVector prodFV = new FeatureVector();
		    addTripFeatures(instance,w1,w2,w3,prodFV);
		    double prodProb = params.getScore(prodFV);
		    fvs_trips[w1][w2][w3] = prodFV;
		    probs_trips[w1][w2][w3] = prodProb;
		}
	    }
	}
			
	for(int w1 = 0; w1 < instanceLength; w1++) {
	    for(int w2 = 0; w2 < instanceLength; w2++) {
		for(int wh = 0; wh < 2; wh++) {
		    if(w1 != w2) {
			FeatureVector prodFV = new FeatureVector();
			addSiblingFeatures(instance,w1,w2,wh == 0,prodFV);
			double prodProb = params.getScore(prodFV);
			fvs_sibs[w1][w2][wh] = prodFV;
			probs_sibs[w1][w2][wh] = prodProb;
		    }
		}
	    }
	}
    }


    private final void addSiblingFeatures(DependencyInstance instance,
					  int ch1, int ch2,
					  boolean isST,
					  FeatureVector fv) {

	String[] forms = instance.forms;
	String[] pos = instance.postags;
		
	// ch1 is always the closes to par
	String dir = ch1 > ch2 ? "RA" : "LA";
		
	String ch1_pos = isST ? "STPOS" : pos[ch1];
	String ch2_pos = pos[ch2];
	String ch1_word = isST ? "STWRD" : forms[ch1];
	String ch2_word = forms[ch2];

	add("CH_PAIR="+ch1_pos+"_"+ch2_pos+"_"+dir,1.0,fv);
	add("CH_WPAIR="+ch1_word+"_"+ch2_word+"_"+dir,1.0,fv);
	add("CH_WPAIRA="+ch1_word+"_"+ch2_pos+"_"+dir,1.0,fv);
	add("CH_WPAIRB="+ch1_pos+"_"+ch2_word+"_"+dir,1.0,fv);
	add("ACH_PAIR="+ch1_pos+"_"+ch2_pos,1.0,fv);
	add("ACH_WPAIR="+ch1_word+"_"+ch2_word,1.0,fv);
	add("ACH_WPAIRA="+ch1_word+"_"+ch2_pos,1.0,fv);
	add("ACH_WPAIRB="+ch1_pos+"_"+ch2_word,1.0,fv);

	int dist = Math.max(ch1,ch2)-Math.min(ch1,ch2);
	String distBool = "0";
	if(dist > 1)
	    distBool = "1";
	if(dist > 2)
	    distBool = "2";
	if(dist > 3)
	    distBool = "3";
	if(dist > 4)
	    distBool = "4";
	if(dist > 5)
	    distBool = "5";
	if(dist > 10)
	    distBool = "10";		
	add("SIB_PAIR_DIST="+distBool+"_"+dir,1.0,fv);
	add("ASIB_PAIR_DIST="+distBool,1.0,fv);
	add("CH_PAIR_DIST="+ch1_pos+"_"+ch2_pos+"_"+distBool+"_"+dir,1.0,fv);
	add("ACH_PAIR_DIST="+ch1_pos+"_"+ch2_pos+"_"+distBool,1.0,fv);
				
    }


    private final void addTripFeatures(DependencyInstance instance,
				       int par,
				       int ch1, int ch2,
				       FeatureVector fv) {

	String[] pos = instance.postags;
		
	// ch1 is always the closest to par
	String dir = par > ch2 ? "RA" : "LA";
		
	String par_pos = pos[par];
	String ch1_pos = ch1 == par ? "STPOS" : pos[ch1];
	String ch2_pos = pos[ch2];

	String pTrip = par_pos+"_"+ch1_pos+"_"+ch2_pos;
	add("POS_TRIP="+pTrip+"_"+dir,1.0,fv);
	add("APOS_TRIP="+pTrip,1.0,fv);
		
    }
	


    /**
     * Write out the second order features.
     *
     **/
    protected void writeExtendedFeatures (DependencyInstance instance, ObjectOutputStream out) 
	throws IOException {

	final int instanceLength = instance.length();

	for(int w1 = 0; w1 < instanceLength; w1++) {
	    for(int w2 = w1; w2 < instanceLength; w2++) {
		for(int w3 = w2+1; w3 < instanceLength; w3++) {
		    FeatureVector prodFV = new FeatureVector();
		    addTripFeatures(instance,w1,w2,w3,prodFV);
		    out.writeObject(prodFV.keys());
		}
	    }
	    for(int w2 = w1; w2 >= 0; w2--) {
		for(int w3 = w2-1; w3 >= 0; w3--) {
		    FeatureVector prodFV = new FeatureVector();
		    addTripFeatures(instance,w1,w2,w3,prodFV);
		    out.writeObject(prodFV.keys());
		}
	    }
	}
			
	out.writeInt(-3);
	
	for(int w1 = 0; w1 < instanceLength; w1++) {
	    for(int w2 = 0; w2 < instanceLength; w2++) {
		for(int wh = 0; wh < 2; wh++) {
		    if(w1 != w2) {
			FeatureVector prodFV = new FeatureVector();
			addSiblingFeatures(instance,w1,w2,wh == 0,prodFV);
			out.writeObject(prodFV.keys());
		    }
		}
	    }
	}
	
	out.writeInt(-3);
    }


    public DependencyInstance readInstance(ObjectInputStream in,
					   int length,
					   FeatureVector[][][] fvs,
					   double[][][] probs,
					   FeatureVector[][][] fvs_trips,
					   double[][][] probs_trips,
					   FeatureVector[][][] fvs_sibs,
					   double[][][] probs_sibs,
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

	    for(int w1 = 0; w1 < length; w1++) {
		for(int w2 = w1; w2 < length; w2++) {
		    for(int w3 = w2+1; w3 < length; w3++) {
			FeatureVector prodFV = new FeatureVector((int[])in.readObject());
			double prodProb = params.getScore(prodFV);
			fvs_trips[w1][w2][w3] = prodFV;
			probs_trips[w1][w2][w3] = prodProb;
		    }
		}
		for(int w2 = w1; w2 >= 0; w2--) {
		    for(int w3 = w2-1; w3 >= 0; w3--) {
			FeatureVector prodFV = new FeatureVector((int[])in.readObject());
			double prodProb = params.getScore(prodFV);
			fvs_trips[w1][w2][w3] = prodFV;
			probs_trips[w1][w2][w3] = prodProb;
		    }
		}
	    }
	    last = in.readInt();
	    if(last != -3) { System.out.println("Error reading file."); System.exit(0); }

	    for(int w1 = 0; w1 < length; w1++) {
		for(int w2 = 0; w2 < length; w2++) {
		    for(int wh = 0; wh < 2; wh++) {
			if(w1 != w2) {
			    FeatureVector prodFV = new FeatureVector((int[])in.readObject());
			    double prodProb = params.getScore(prodFV);
			    fvs_sibs[w1][w2][wh] = prodFV;
			    probs_sibs[w1][w2][wh] = prodProb;
			}
		    }
		}
	    }
	    last = in.readInt();
	    if(last != -3) { System.out.println("Error reading file."); System.exit(0); }
	    
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
		
}
