#include "device_launch_parameters.h"
#include <cuda_runtime.h>

#include <stdio.h>

#include <cuda_runtime.h>
#include <iostream>
#include <string>
#include <fstream>
#include <cstring>

using namespace std;

// Kernel to search for patterns in rows of data
// Kernel to search for patterns in rows of data
__global__ void searchPattern(const char* inputRows, int numRows, int numColumns, const char* pattern, int patternLength, int* results) {
    int tid = blockIdx.x * blockDim.x + threadIdx.x;
    printf("TID: %d\n", tid);
    if (tid < numRows) {
        // Calculate the starting index of the row
        int rowStartIndex = tid * numColumns;

        // Get a pointer to the start of the row
        const char* row = inputRows + rowStartIndex;

        int matchCount = 0;
        printf("Thread %d is processing row %d\n", tid, tid + 1);
        printf("Row content: ");
        for (int k = 0; k < numColumns; ++k) {
            printf("%c", row[k]);
        }
        printf("\n");
        for (int i = 0; i <= numColumns - patternLength; ++i) {
            int columnNumber;
          //  printf("Thread %d is checking position %d in row %d\n", tid, i, tid + 1);
            bool match = true;
         //   printf("pattern length is %d\n", patternLength);
            for (int j = 0; j < patternLength; ++j) {
                // printf("TID: %d  COMPARING %d TO %d\n", tid, row[i + j], pattern[j]);
                if (row[i + j] != pattern[j]) {
                  //  printf("TID: %d  PATTERN BROKEN AT %d , %d\n", tid, tid + 1, i + j + tid + 1);
                    match = false;
                    break;
                }
                else if (row[i + j] == pattern[j] && j == 0)
                {
                    columnNumber = i + j + 1;
                    //printf("TID: %d  PATTERN FOUND AT %d , %d\n", tid, tid + 1, i + j + 1);
                }
                else if (row[i + j] == pattern[j] && j == patternLength - 1)
                {
                  // printf("TID: %d  COMPLETED PATTERN AT %d , %d\n", tid, tid + 1, i + j + 1);
                }
            }
            if (match) {
                // Calculate the position of the match within the row
                // Store the position of the match in the results array along with the row and column numbers
                results[(tid * numColumns + matchCount) * 2] = tid + 1; // Row number
                printf("%d\n", (tid * numColumns + matchCount) * 2);

                results[(tid * numColumns + matchCount) * 2 + 1] = columnNumber; // Column number
                printf("%d\n", (tid * numColumns + matchCount) * 2 + 1);
                matchCount++;
                printf("Thread %d found a match at position (%d, %d)\n", tid, tid + 1, columnNumber);
            }
        }
        // Mark the end of matches for this row
        results[(tid * numColumns + matchCount) * 2] = -1;
        results[(tid * numColumns + matchCount) * 2 + 1] = -1;
    }
}




int main() {
    // Define input, pattern, and output file paths
    string inputFileName = "C:/Users/MaristUser/source/repos/PatternSearcher/x64/Debug/input.txt";
    string patternFileName = "C:/Users/MaristUser/source/repos/PatternSearcher/x64/Debug/pattern.txt";
    string outputFileName = "C:/Users/MaristUser/source/repos/PatternSearcher/x64/Debug/output.txt";

    // Open input, pattern, and output files
    ifstream inputFile(inputFileName);
    ifstream patternFile(patternFileName);
    ofstream outputFile(outputFileName);

    // Check if files are opened successfully
    if (!inputFile || !patternFile || !outputFile) {
        cerr << "Error opening files." << endl;
        return 1;
    }

    // Read the first line of the input and pattern files
    string inputLine, patternLine;
    getline(patternFile, patternLine);
    // Calculate the number of columns and rows in the input file
    int numColumns;
    int numRows = 0;

    string inputString;
    while (getline(inputFile, inputLine)) {
        inputString += inputLine; // Append each line to the inputString with a newline character
        ++numRows;
    }
    numColumns = inputLine.length();

    printf("the number of rows is %d\n", numRows);

    // Allocate memory on GPU
    char* inputRowsDevice;
    char* patternDevice;
    int* resultsDevice;
    int* resultsHost = new int[numRows * numColumns * 2]; // Results array stores both row and column numbers

    cudaMalloc((void**)&inputRowsDevice, numRows * numColumns * sizeof(char));
    cudaMalloc((void**)&patternDevice, patternLine.length() * sizeof(char));
    cudaMalloc((void**)&resultsDevice, numRows * numColumns * 2 * sizeof(int)); // Each match has two integers (row and column)

    // Copy input data and pattern from CPU to GPU
    cudaMemcpy(inputRowsDevice, inputString.c_str(), numRows * numColumns * sizeof(char), cudaMemcpyHostToDevice);
    cudaMemcpy(patternDevice, patternLine.c_str(), patternLine.length() * sizeof(char), cudaMemcpyHostToDevice);

    // Invoke the CUDA kernel
    int threadsPerBlock = 256;
    int blocksPerGrid = (numRows + threadsPerBlock) / threadsPerBlock;
    printf("row: %s\n", inputString.c_str());
    searchPattern << <1, numRows >> > (inputRowsDevice, numRows, numColumns, patternDevice, patternLine.length(), resultsDevice);

    // Copy results back from GPU to CPU
    cudaMemcpy(resultsHost, resultsDevice, numRows * numColumns * 2 * sizeof(int), cudaMemcpyDeviceToHost);
 

    // Process results on CPU and write to output file
    for (int i = 0; i < numRows * numColumns * 2; i += 2) {
        int row = resultsHost[i];
        printf("ROW: %d ", row);

        int col = resultsHost[i + 1];
        printf(" COL: %d ", col);

        if (row > 0 && col > 0) {
            outputFile << "Pattern found at position: (" << row << ", " << col << ")" << endl;
        }
    }

    // Free allocated memory on GPU
    cudaFree(inputRowsDevice);
    cudaFree(patternDevice);
    cudaFree(resultsDevice);

    // Close files
    inputFile.close();
    patternFile.close();
    outputFile.close();

    // Deallocate memory
    delete[] resultsHost;

    return 0;
}

