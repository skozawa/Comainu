package mstparser;

import java.io.*;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import gnu.trove.*;
import java.text.DecimalFormat;

public class DependencyDecoder2O extends DependencyDecoder {

    public DependencyDecoder2O(DependencyPipe pipe) {
	super(pipe);
    }

    private void rearrange(double[][][] probs,
			   double[][][] probs_trips,
			   double[][][] probs_sibs, double[][][][] nt_probs, int[] par, int[] labs) {
		
	int[][] static_types = null;
	if(pipe.labeled) {
	    static_types = getTypes(nt_probs,par.length);
	}

	boolean[][] isChild = calcChilds(par);
	boolean[][] isCross = null;
		
	while(true) {
	    int wh = -1;
	    int nPar = -1;
	    int nType = -1;
	    double max = Double.NEGATIVE_INFINITY;
	    int[][] aSibs = new int[par.length][par.length];
	    int[][] bSibs = new int[par.length][par.length];
	    for(int i = 1; i < par.length; i++) {
		for(int j = 0; j < par.length; j++) {
		    int oP = par[i];
		    par[i] = j;
		    int[] sibs = getSibs(i,par);
		    aSibs[i][j] = sibs[0]; bSibs[i][j] = sibs[1];
		    par[i] = oP;
		}
	    }
	    for(int ch = 1; ch < par.length; ch++) {
		// Calculate change of removing edge
		int aSib = aSibs[ch][par[ch]]; int bSib = bSibs[ch][par[ch]];
		boolean lDir = ch < par[ch];
		double change = 0.0 - probs[lDir ? ch : par[ch]][lDir ? par[ch] : ch][lDir ? 1 : 0]
		    - probs_trips[par[ch]][aSib][ch] - probs_sibs[aSib][ch][aSib == par[ch] ? 0 : 1]
		    - (bSib != ch ? probs_trips[par[ch]][ch][bSib] + probs_sibs[ch][bSib][1] : 0.0)
		    - (pipe.labeled ? (nt_probs[ch][labs[ch]][lDir ? 1 : 0][0] + nt_probs[par[ch]][labs[ch]][lDir ? 1 : 0][1]) : 0.0)
		    + (bSib != ch ? probs_trips[par[ch]][aSib][bSib] + probs_sibs[aSib][bSib][aSib == par[ch] ? 0 : 1] : 0.0);
		for(int pa = 0; pa < par.length; pa++) {
		    if(ch == pa || pa == par[ch] || isChild[ch][pa]) continue;
		    aSib = aSibs[ch][pa]; bSib = bSibs[ch][pa];
		    boolean lDir1 = ch < pa;
		    double change1 = 0.0 + probs[lDir1 ? ch : pa][lDir1 ? pa : ch][lDir1 ? 1 : 0]
			+ probs_trips[pa][aSib][ch] + probs_sibs[aSib][ch][aSib == pa ? 0 : 1]
			+ (bSib != ch ? probs_trips[pa][ch][bSib] + probs_sibs[ch][bSib][1] : 0.0)
			+ (pipe.labeled ? (nt_probs[ch][static_types[pa][ch]][lDir1 ? 1 : 0][0] + nt_probs[pa][static_types[pa][ch]][lDir1 ? 1 : 0][1]) : 0.0)
			- (bSib != ch ? probs_trips[pa][aSib][bSib] + probs_sibs[aSib][bSib][aSib == pa ? 0 : 1] : 0.0);
		    if(max < change+change1) {
			max = change+change1; wh = ch; nPar = pa; nType = pipe.labeled ? static_types[pa][ch] : 0;
		    }
		}
	    }
	    if(max <= 0.0)
		break;
	    par[wh] = nPar;
	    labs[wh] = nType;
	    isChild = calcChilds(par);
	    //System.out.println(max + " " + wh + " " + nPar + " " + nType);
	}
    }
	
    // same as decode, except return K best
    public Object[][] decodeNonProjective(DependencyInstance inst,
					  FeatureVector[][][] fvs,
					  double[][][] probs,
					  FeatureVector[][][] fvs_trips,
					  double[][][] probs_trips,
					  FeatureVector[][][] fvs_sibs,
					  double[][][] probs_sibs,
					  FeatureVector[][][][] nt_fvs,
					  double[][][][] nt_probs, int K) {

	String[] forms = inst.forms;
	String[] pos = inst.postags;

	Object[][] orig = decodeProjective(inst,fvs,probs,fvs_trips,probs_trips,fvs_sibs,probs_sibs,nt_fvs,nt_probs,1);
	String[] o = ((String)orig[0][1]).split(" ");
	int[] par = new int[o.length+1];
	int[] labs = new int[o.length+1];
	labs[0] = 0;
	par[0] = -1;
	for(int i = 1; i < par.length; i++) {
	    par[i] = Integer.parseInt(o[i-1].split("\\|")[0]);
	    labs[i] = pipe.labeled ? Integer.parseInt(o[i-1].split(":")[1]) : 0;
	}

	rearrange(probs,probs_trips,probs_sibs,nt_probs,par,labs);
		
	String pars = "";
	for(int i = 1; i < par.length; i++)
	    pars += par[i]+"|"+i+":"+labs[i]+" ";

	inst.heads = par;

	inst.deprels = new String[labs.length];
	for(int i = 0; i < labs.length; i++)
	    inst.deprels[i] = pipe.getType(labs[i]);

	orig[0][0] = ((DependencyPipe2O)pipe).createFeatureVector(inst);
	orig[0][1] = pars;
		

	return orig;
    }

    private boolean[][] calcChilds(int[] par) {
	boolean[][] isChild = new boolean[par.length][par.length];
	for(int i = 1; i < par.length; i++) {
	    int l = par[i];
	    while(l != -1) {
		isChild[l][i] = true;
		l = par[l];
	    }
	}
	return isChild;
    }

    private int[] getSibs(int ch, int[] par) {
	int aSib = par[ch];
	if(par[ch] > ch)
	    for(int i = ch+1; i < par[ch]; i++) {
		if(par[i] == par[ch]) {
		    aSib = i; break;
		}
	    }
	else
	    for(int i = ch-1; i > par[ch]; i--) {
		if(par[i] == par[ch]) {
		    aSib = i; break;
		}
	    }
	int bSib = ch;
	if(par[ch] < ch)
	    for(int i = ch+1; i < par.length; i++) {
		if(par[i] == par[ch]) {
		    bSib = i; break;
		}
	    }
	else
	    for(int i = ch-1; i >=0; i--) {
		if(par[i] == par[ch]) {
		    bSib = i; break;
		}
	    }
	return new int[]{aSib,bSib};
    }
		
    // same as decode, except return K best
    public Object[][] decodeProjective(DependencyInstance inst,
				       FeatureVector[][][] fvs,
				       double[][][] probs,
				       FeatureVector[][][] fvs_trips,
				       double[][][] probs_trips,
				       FeatureVector[][][] fvs_sibs,
				       double[][][] probs_sibs,
				       FeatureVector[][][][] nt_fvs,
				       double[][][][] nt_probs, int K) {
		
	String[] forms = inst.forms;
	String[] pos = inst.postags;
		
	int[][] static_types = null;
	if(pipe.labeled) {
	    static_types = getTypes(nt_probs,forms.length);
	}

	KBestParseForest2O pf = new KBestParseForest2O(0,forms.length-1,inst,K);
		
	for(int s = 0; s < forms.length; s++) {
	    pf.add(s,-1,0,0.0,new FeatureVector());
	    pf.add(s,-1,1,0.0,new FeatureVector());
	}
		
	for(int j = 1; j < forms.length; j++) {
	    for(int s = 0; s < forms.length && s+j < forms.length; s++) {
		int t = s+j;
				
		FeatureVector prodFV_st = fvs[s][t][0];
		FeatureVector prodFV_ts = fvs[s][t][1];				
		double prodProb_st = probs[s][t][0];
		double prodProb_ts = probs[s][t][1];
				
		int type1 = pipe.labeled ? static_types[s][t] : 0;
		int type2 = pipe.labeled ? static_types[t][s] : 0;
		
		FeatureVector nt_fv_s_01 = nt_fvs[s][type1][0][1];
		FeatureVector nt_fv_s_10 = nt_fvs[s][type2][1][0];
		FeatureVector nt_fv_t_00 = nt_fvs[t][type1][0][0];
		FeatureVector nt_fv_t_11 = nt_fvs[t][type2][1][1];
		double nt_prob_s_01 = nt_probs[s][type1][0][1];
		double nt_prob_s_10 = nt_probs[s][type2][1][0];
		double nt_prob_t_00 = nt_probs[t][type1][0][0];
		double nt_prob_t_11 = nt_probs[t][type2][1][1];
		double prodProb = 0.0;

		if(true) {
		    // case when r == s
		    ParseForestItem[] b1 = pf.getItems(s,s,0,0);
		    ParseForestItem[] c1 = pf.getItems(s+1,t,1,0);
		    if(!(b1 == null || c1 == null)) {
						
			FeatureVector prodFV_sst = pf.cat(fvs_trips[s][s][t],fvs_sibs[s][t][0]);
			double prodProb_sst = probs_trips[s][s][t]+probs_sibs[s][t][0];
						
			int[][] pairs = pf.getKBestPairs(b1,c1);
						
			for(int k = 0; k < pairs.length; k++) {
							
			    if(pairs[k][0] == -1 || pairs[k][1] == -1)
				break;
							
			    int comp1 = pairs[k][0]; int comp2 = pairs[k][1];
							
			    double bc = b1[comp1].prob+c1[comp2].prob;
							
			    // create sibling pair
			    // create parent pair: s->t and s->(start,t)
			    bc += prodProb_st + prodProb_sst;
			    
			    FeatureVector fv_fin = pf.cat(prodFV_st,prodFV_sst);
			    if(pipe.labeled) {
				bc += nt_prob_s_01+nt_prob_t_00;
				fv_fin = nt_fv_s_01.cat(nt_fv_t_00.cat(fv_fin));
			    }

			    pf.add(s,s,t,type1,0,1,bc,fv_fin,b1[comp1],c1[comp2]);

			}
		    }
					
		    // case when r == t
		    b1 = pf.getItems(s,t-1,0,0);
		    c1 = pf.getItems(t,t,1,0);
		    if(!(b1 == null || c1 == null)) {
						
			FeatureVector prodFV_stt = pf.cat(fvs_trips[t][t][s],fvs_sibs[t][s][0]);
			double prodProb_stt = probs_trips[t][t][s]+probs_sibs[t][s][0];

			int[][] pairs = pf.getKBestPairs(b1,c1);
						
			for(int k = 0; k < pairs.length; k++) {
							
			    if(pairs[k][0] == -1 || pairs[k][1] == -1)
				break;
							
			    int comp1 = pairs[k][0]; int comp2 = pairs[k][1];
							
			    double bc = b1[comp1].prob+c1[comp2].prob;
							
			    // create sibling pair
			    // create parent pair: s->t and s->(start,t)
			    bc += prodProb_ts + prodProb_stt;
			    
			    FeatureVector fv_fin = pf.cat(prodFV_ts,prodFV_stt);
			    if(pipe.labeled) {
				bc += nt_prob_t_11+nt_prob_s_10;
				fv_fin = nt_fv_t_11.cat(nt_fv_s_10.cat(fv_fin));
			    }

			    pf.add(s,t,t,type2,1,1,bc,fv_fin,b1[comp1],c1[comp2]);
			}
		    }
		}
				
		for(int r = s; r < t; r++) {

		    // First case - create sibling
		    ParseForestItem[] b1 = pf.getItems(s,r,0,0);
		    ParseForestItem[] c1 = pf.getItems(r+1,t,1,0);
					
		    if(!(b1 == null || c1 == null)) {
					
			int[][] pairs = pf.getKBestPairs(b1,c1);
						
			for(int k = 0; k < pairs.length; k++) {
							
			    if(pairs[k][0] == -1 || pairs[k][1] == -1)
				break;
							
			    int comp1 = pairs[k][0]; int comp2 = pairs[k][1];
							
			    double bc = b1[comp1].prob+c1[comp2].prob;
							
			    pf.add(s,r,t,-1,0,2,bc,new FeatureVector(),b1[comp1],c1[comp2]);
			    pf.add(s,r,t,-1,1,2,bc,new FeatureVector(),b1[comp1],c1[comp2]);
			}
		    }
		}
				
		for(int r = s+1; r < t; r++) {
		    // s -> (r,t)
		    ParseForestItem[] b1 = pf.getItems(s,r,0,1);
		    ParseForestItem[] c1 = pf.getItems(r,t,0,2);
					
		    if(!(b1 == null || c1 == null)) {
					
			int[][] pairs = pf.getKBestPairs(b1,c1);
						
			for(int k = 0; k < pairs.length; k++) {
							
			    if(pairs[k][0] == -1 || pairs[k][1] == -1)
				break;
							
			    int comp1 = pairs[k][0]; int comp2 = pairs[k][1];
							
			    double bc = b1[comp1].prob+c1[comp2].prob;

			    bc += prodProb_st + probs_trips[s][r][t] + probs_sibs[r][t][1];
			    FeatureVector fv_fin = pf.cat(prodFV_st,pf.cat(fvs_trips[s][r][t],fvs_sibs[r][t][1]));

			    if(pipe.labeled) {
				bc += nt_prob_s_01+nt_prob_t_00;
				fv_fin = nt_fv_s_01.cat(nt_fv_t_00.cat(fv_fin));
			    }

			    pf.add(s,r,t,type1,0,1,bc,fv_fin,b1[comp1],c1[comp2]);
			}
		    }
					
		    // t -> (r,s)
		    b1 = pf.getItems(s,r,1,2);
		    c1 = pf.getItems(r,t,1,1);
					
		    if(!(b1 == null || c1 == null)) {
					
			int[][] pairs = pf.getKBestPairs(b1,c1);
						
			for(int k = 0; k < pairs.length; k++) {
							
			    if(pairs[k][0] == -1 || pairs[k][1] == -1)
				break;
							
			    int comp1 = pairs[k][0]; int comp2 = pairs[k][1];
							
			    double bc = b1[comp1].prob+c1[comp2].prob;

			    bc += prodProb_ts + probs_trips[t][r][s] + probs_sibs[r][s][1];
			    
			    FeatureVector fv_fin = pf.cat(prodFV_ts,pf.cat(fvs_trips[t][r][s],fvs_sibs[r][s][1]));
			    if(pipe.labeled) {
				bc += nt_prob_t_11+nt_prob_s_10;
				fv_fin = nt_fv_t_11.cat(nt_fv_s_10.cat(fv_fin));
			    }

			    pf.add(s,r,t,type2,1,1,bc,fv_fin,b1[comp1],c1[comp2]);
			}
		    }
					
		}


		// Finish off pieces incom + comp -> comp
		for(int r = s; r <= t; r++) {

		    if(r != s) {
			ParseForestItem[] b1 = pf.getItems(s,r,0,1);
			ParseForestItem[] c1 = pf.getItems(r,t,0,0);

			if(!(b1 == null || c1 == null)) {
			    //continue;
						
			    int[][] pairs = pf.getKBestPairs(b1,c1);
			    for(int k = 0; k < pairs.length; k++) {
								
				if(pairs[k][0] == -1 || pairs[k][1] == -1)
				    break;
								
				int comp1 = pairs[k][0]; int comp2 = pairs[k][1];
								
				double bc = b1[comp1].prob+c1[comp2].prob;
								
				if(!pf.add(s,r,t,-1,0,0,bc,new FeatureVector(),b1[comp1],c1[comp2]))
				    break;
			    }
			}
		    }
					
		    if(r != t) {
			ParseForestItem[] b1 = pf.getItems(s,r,1,0);
			ParseForestItem[] c1 = pf.getItems(r,t,1,1);

			if(!(b1 == null || c1 == null)) {
			    //continue;

			    int[][] pairs = pf.getKBestPairs(b1,c1);
			    for(int k = 0; k < pairs.length; k++) {
								
				if(pairs[k][0] == -1 || pairs[k][1] == -1)
				    break;
								
				int comp1 = pairs[k][0]; int comp2 = pairs[k][1];
								
				double bc = b1[comp1].prob+c1[comp2].prob;
								
				if(!pf.add(s,r,t,-1,1,0,bc,new FeatureVector(),b1[comp1],c1[comp2]))
				    break;
			    }
			}
		    }

		}
				
	    }
	}

	return pf.getBestParses();
    }

}
