// This program executes a typical Interval Join
#include <iostream>
#include <omp.h>
#include "intervalJoin.h"
using namespace std;

#define N 1024
#define THREADS_PER_BLOCK 1024

struct node 
{ 
	int middle;
    int *start,*end,*index; 
    int length;
    struct node *left, *right; 
}; 
   
struct node *newNode(int middle,int *start, int *end, int start_idx,int end_idx) 
{ 
	int i;
    struct node *temp =  (struct node *)malloc(sizeof(struct node)); 
    temp->middle=middle;
    temp->length=end_idx-start_idx+1;
    temp->start = (int*)malloc(temp->length*sizeof(int));
	temp->end = (int*)malloc(temp->length*sizeof(int));
	temp->index = (int*)malloc(temp->length*sizeof(int));
	for(i=0;i<temp->length;i++){
		temp->start[i]=start[start_idx+i];
		temp->end[i]=end[start_idx+i];
		temp->index[i]=start_idx+i;
	} 
	temp->left = temp->right = NULL; 
    return temp; 
}
   
void search(struct node *node, int start, int end, int index) 
{ 
	int i;
    if (node != NULL) 
    { 
    	for(i=0;i<node->length;i++){
    		if((node->start[i]<=start && start<=node->end[i]) || (node->start[i]<=end && end<=node->end[i]) || (node->start[i]<=start && end<=node->end[i]) || (node->start[i]>=start && end>=node->end[i])){
    			if(node->index[i]<start_index[index])
    				start_index[index]=node->index[i];
    			if(node->index[i]>end_index[index])
    				end_index[index]=node->index[i];  				
			}				
		}
    	if(start<=node->middle && node->middle<=end){
        	search(node->left,start,end, index); 
        	search(node->right,start,end, index);	
		}
        else if(end<node->middle)
        	search(node->left,start,end, index);
        else if(node->middle<start)
        	search(node->right,start,end, index);
    }
} 


struct node* make_tree(struct node* node,int *input_start, int *input_end,int array_start, int array_end){
	int i;
	int middle;
	int start_idx=-1,end_idx=-1;
	if(array_start<=array_end){
		middle=(input_start[array_start]+input_end[array_end])/2;
		for(i=array_start;i<=array_end;i++){
			if(input_start[i]<=middle && middle<=input_end[i]){
				if(start_idx==-1){
					start_idx=i;
				}
				end_idx=i;
			}
		}
		i=0;
		if(start_idx==-1 && end_idx==-1){
			while(input_end[i]<=middle)
				i++;
			start_idx=i-1;
			while(input_start[i]<middle)
				i++;
			end_idx=i-1;
		}
   
		node=newNode(middle, input_start,input_end,start_idx,end_idx);
	}
	if(start_idx>=0 && array_start>=0 && start_idx-1>=array_start)
		node->left=make_tree(node,input_start, input_end,array_start,start_idx-1);
	
			
	if(start_idx>=0 && end_idx+1<=array_end)
		node->right=make_tree(node,input_start, input_end,end_idx+1,array_end);
	
	return node;	
}


// This is the CPU version, please don't modify it
void intervalJoinCPU(int id)
{
	int i;
	struct node* root=NULL;
	int search_size= setB.length[id] * sizeof(int);
    start_index=(int*)malloc(search_size);
    end_index=(int*)malloc(search_size);
	
    root=make_tree(root,inStartA,inEndA,0,setA.length[id]-1);
    //inorder(root);
	
	for(i=0;i<setB.length[id];i++){
        start_index[i]=INT_MAX;
        end_index[i]=INT_MIN;
		search(root,inStartB[i],inEndB[i],i);
        outCPU_Begin[i]=start_index[i];
        outCPU_End[i]=end_index[i];
		if(start_index[i] != INT_MAX) {
			printf("%d; %d; %d; %d; %d; %d; %d;\n", *inStartA, *inEndA, i, inStartB[i], inEndB[i], outCPU_Begin[i], outCPU_End[i]);
		}
    }
	int total_intersects=0;
        for(i=0;i<setB.length[id];i++){
                if(outCPU_Begin[i]<INT_MAX && outCPU_End[i]>INT_MIN){
                        total_intersects+=(outCPU_End[i]-outCPU_Begin[i]+1);
        }
    }
	free(start_index);
	free(end_index);
}

/***	Implement your CUDA Kernel here	***/
__global__
void intervalJoinGPU(int *dev_inStartA, int *dev_inEndA, int *dev_inStartB, int *dev_inEndB, int *dev_outStart, int *dev_outEnd, int dev_lengthA, int dev_lengthB)
{
	int indexB = threadIdx.x + blockIdx.x * blockDim.x;	
	
	if(indexB<=dev_lengthB) {
		for(int indexA=0; indexA<dev_lengthA; indexA++) {
			__syncthreads();
			if(dev_outStart[indexB] == INT_MAX  && 
					(
						( dev_inStartA[indexA]>=dev_inStartB[indexB] && dev_inStartA[indexA]<=dev_inEndB[indexB] ) || //first case
						( dev_inEndA[indexA]>=dev_inStartB[indexB] && dev_inEndA[indexA]<=dev_inEndB[indexB] ) || //second case
						( dev_inStartA[indexA]>=dev_inStartB[indexB] && dev_inEndA[indexA]<=dev_inEndB[indexB] ) || //third case
						( dev_inStartA[indexA]<=dev_inStartB[indexB] && dev_inEndA[indexA]>=dev_inEndB[indexB] ) //fourth case
					)
				)
			{
				dev_outStart[indexB] = indexA;
				dev_outEnd[indexB] = indexA;
				__syncthreads();
			}
			else if (
						( dev_inStartA[indexA]>=dev_inStartB[indexB] && dev_inStartA[indexA]<=dev_inEndB[indexB] ) || //first case
						( dev_inEndA[indexA]>=dev_inStartB[indexB] && dev_inEndA[indexA]<=dev_inEndB[indexB] ) || //second case
						( dev_inStartA[indexA]>=dev_inStartB[indexB] && dev_inEndA[indexA]<=dev_inEndB[indexB] ) || //third case
						( dev_inStartA[indexA]<=dev_inStartB[indexB] && dev_inEndA[indexA]>=dev_inEndB[indexB] ) //fourth case
					)
			{
				dev_outEnd[indexB] = dev_outEnd[indexB] + 1;
				__syncthreads();
			}
		}
	}
/* 	__syncthreads();
	if(dev_outEnd[indexB] != INT_MIN) {
		printf("%d; %d; %d; %d; %d; %d; %d;\n", *dev_inStartA, *dev_inEndA, indexB, dev_inStartB[indexB], dev_inEndB[indexB], dev_outStart[indexB], dev_outEnd[indexB]);	
	}
	__syncthreads(); */
}
/***	Implement your CUDA Kernel here	***/

int main(){

	int i;
	timespec time_begin, time_end;
	int intervalJoinCPUExecTime, intervalJoinGPUExecTime;
	int cpuTotalTime=0,gpuTotalTime=0; 
	FILE *fpA, *fpB;
	int *dev_inStartA, *dev_inStartB, *dev_inEndA, *dev_inEndB, *dev_outStart, *dev_outEnd;
	int NbBlocks;
	
	read_Meta();
	
	fpA = fopen ("data/dataA.csv","r");
	fpB = fopen ("data/dataB.csv","r");
	
	//for(i=0;i<setA.count;i++){
		i=0;
		init_from_csv(fpA, fpB, i);

 		clock_gettime(CLOCK_REALTIME, &time_begin);
		intervalJoinCPU(i);
		clock_gettime(CLOCK_REALTIME, &time_end);
		intervalJoinCPUExecTime = timespec_diff_us(time_begin, time_end);
		cout << "CPU time for executing a typical Interval Join = " <<  intervalJoinCPUExecTime / 1000 << "ms" << endl;
		cpuTotalTime+=intervalJoinCPUExecTime;
		
/*   	for(int k=0;k<setB.length[i];k++)
		{
			if(outCPU_Begin[k] != INT_MAX) {
				printf("%d; %d; %d; \n",k,outCPU_Begin[k],outCPU_End[k]);
			}	
		} */
		clock_gettime(CLOCK_REALTIME, &time_begin);
		
		 /***Do the required GPU Memory allocation here***/
		cudaMalloc((void **)&dev_inStartA, (setA.length[i] * sizeof(int)));
		cudaMalloc((void **)&dev_inEndA, (setA.length[i] * sizeof(int)));
		cudaMalloc((void **)&dev_inStartB, (setB.length[i] * sizeof(int)));
		cudaMalloc((void **)&dev_inEndB, (setB.length[i] * sizeof(int)));
		cudaMalloc((void **)&dev_outStart, (setB.length[i] * sizeof(int)));
		cudaMalloc((void **)&dev_outEnd, (setB.length[i] * sizeof(int)));
		
		/***Do the required GPU Memory allocation here***/
		
		/*Copy inputs to the device*/
		cudaMemcpy( dev_inStartA, inStartA, (setA.length[i] * sizeof(int)), cudaMemcpyHostToDevice );
		cudaMemcpy( dev_inEndA, inEndA, (setA.length[i] * sizeof(int)), cudaMemcpyHostToDevice ); 
		cudaMemcpy( dev_inStartB, inStartB, (setB.length[i] * sizeof(int)), cudaMemcpyHostToDevice ); 
		cudaMemcpy( dev_inEndB, inEndB, (setB.length[i] * sizeof(int)), cudaMemcpyHostToDevice ); 
		cudaMemcpy( dev_outStart, outGPU_Begin, (setB.length[i] * sizeof(int)), cudaMemcpyHostToDevice ); 
		cudaMemcpy( dev_outEnd, outGPU_End, (setB.length[i] * sizeof(int)), cudaMemcpyHostToDevice ); 

		/*Copy inputs to the device*/

		if (setB.length[i]%N == 0){
			NbBlocks = (setB.length[i])/(THREADS_PER_BLOCK);
		}
		else{
			NbBlocks = ((setB.length[i])/(THREADS_PER_BLOCK)) + 1;
		}

		/***Configure the CUDA Kernel call here***/
		//intervalJoinGPU<<<NbBlocks,THREADS_PER_BLOCK>>>(dev_inStartA, dev_inEndA, dev_inStartB, dev_inEndB, dev_outStart, dev_outEnd, setA.length[i], setB.length[i]); // Lunch the kernel
		
		cudaDeviceSynchronize(); // Do synchronization before clock_gettime()
		
		/***Copy back the result from GPU Memory to CPU memory arrays outGPU_Begin and outGPU_End***/
		cudaMemcpy( outGPU_Begin, dev_outStart, sizeof(outGPU_Begin), cudaMemcpyDeviceToHost  ); 
		cudaMemcpy( outGPU_End, dev_outEnd, sizeof(outGPU_End), cudaMemcpyDeviceToHost  );
		/***Copy back the result from GPU Memory to CPU memory arrays outGPU_Begin and outGPU_End***/
		
/* 		for(int k=0;k<setB.length[i];k++)
		{
			if(outGPU_Begin[k] != INT_MAX) {
				printf("%d; %d; %d; \n",k,outGPU_Begin[k],outGPU_End[k]);
			}	
		} */
		
		clock_gettime(CLOCK_REALTIME, &time_end);
		intervalJoinGPUExecTime = timespec_diff_us(time_begin, time_end);
		//cout << "GPU time for executing a typical Interval Join = " << intervalJoinGPUExecTime / 1000 << "ms" << endl;
		cpuTotalTime+=intervalJoinGPUExecTime;
		
/* 		if(checker(setB.length[i])){
			cout << "Congratulations! You pass the check." << endl;
			cout << "Speedup: " << (float)intervalJoinCPUExecTime / intervalJoinGPUExecTime << endl;
		}
		else
			cout << "Sorry! Your result is wrong." << endl; */

		
			
		cudaFree( dev_inStartA ); 
		cudaFree( dev_inEndA );
		cudaFree( dev_inStartB );
		cudaFree( dev_inEndB ); 
		cudaFree( dev_outStart ); 
		cudaFree( dev_outEnd ); 
		ending();
		
	//}

	
	
	fclose(fpA);
	fclose(fpB);

	return 0;
}
