/*
    Copyright 2017 Zheyong Fan, Ville Vierimaa, Mikko Ervasti, and Ari Harju
    This file is part of GPUMD.
    GPUMD is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
    GPUMD is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
    You should have received a copy of the GNU General Public License
    along with GPUMD.  If not, see <http://www.gnu.org/licenses/>.
*/




#include "gpumd.cuh"
#include "error.cuh"

#include <stdlib.h>
#include <stdio.h>
#include <time.h>




int main(int argc, char *argv[])
{
    printf("\n");
    printf("***************************************************************\n");
    printf("*                 Welcome to use GPUMD                        *\n");
    printf("*     (Graphics Processing Units Molecular Dynamics)          *\n");
    printf("*                      Version 2.1                            *\n");
    printf("*       (Author:  Zheyong Fan <brucenju@gmail.com>)           *\n");
    printf("***************************************************************\n");
    printf("\n");

    print_line_1();
    printf("Compiling options:\n");
    print_line_2();

#ifdef DEBUG
    printf("DEBUG is on\n");
#else
    srand(time(NULL));
    printf("DEBUG is off\n");
#endif

#ifdef USE_DP
    printf("USE_DP is on\n");
#else
    printf("USE_DP is off\n");
#endif

#ifdef TERSOFF_CUTOFF
    printf("TERSOFF_CUTOFF is on\n");
#else
    printf("TERSOFF_CUTOFF is off\n");
#endif

    // get the number of input directories
    int number_of_inputs;
    char input_directory[200];

    int count = scanf("%d", &number_of_inputs);
    if (count != 1)
    {
        printf("Error: reading error for number of inputs.\n");
        exit(1);
    }

    // Run GPUMD for the input directories one by one
    for (int n = 0; n < number_of_inputs; ++n)
    {
        count = scanf("%s", input_directory);
        if (count != 1)
        {
            printf("Error: reading error for input directory.\n");
            exit(1);
        }

        print_line_1();
        printf("Run simulation for '%s'.\n", input_directory);
        print_line_2();

        clock_t time_begin = clock();

        // Run GPUMD for "input_directory"
        GPUMD gpumd(input_directory);

        clock_t time_finish = clock();

        double time_used = (time_finish - time_begin) / double(CLOCKS_PER_SEC);

        print_line_1();
        printf("Time used for '%s' = %f s.\n", input_directory, time_used);
        print_line_2();
    }

    return EXIT_SUCCESS;
}




