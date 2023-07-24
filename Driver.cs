using System;

using Microsoft.Quantum.Simulation.Core;
using Microsoft.Quantum.Simulation.Simulators;

namespace QRL_App
{
    class Driver
    {
        static void Main(string[] args)
        {
            using (var qsim = new QuantumSimulator())
            {
                //Substract the junktime from the calling of DateTime.Now function (not necessary)
                DateTime junktime1 = DateTime.Now;
                DateTime junktime2 = DateTime.Now;
                TimeSpan junktime = junktime2.Subtract(junktime1);


                //Ask the wanted iterations for the quantum algorithm to repeat
                //System.Console.WriteLine("How many iterations would you like?");
                //int iterations = Int32.Parse(Console.ReadLine());
                

                //QCTraceSimulator sim = new QCTraceSimulator();
                //ResourcesEstimator resourceEstimator = new ResourcesEstimator();
                //Console.WriteLine(resourceEstimator.ToTSV());


                //Start counting the time and run the quantum algorithm with belonging parameters
                DateTime start = DateTime.Now;
                //double [] rw = new double[] {2,0,1,0,0,1,
                //                             0,2,0,0,0,1,
                //                             0,1,2,1,0,1,
                //                             1,1,0,2,1,0,
                //                             0,0,0,1,2,0,
                //                             1,0,1,0,1,2,
                //                             1,0,1,1,0,0,
                //                             0,1,1,0,1,1};

                //double[] rw = new double[] {2,0,0,0,0,0,0,0,
                //                            0,2,0,0,0,0,0,0,
                //                            0,0,2,0,0,0,0,0,
                //                            0,0,0,2,0,0,0,0,
                //                            0,0,0,0,2,0,0,0,
                //                            0,0,0,0,0,2,0,0};

                //double[] rewards = new double[] {-3.0, -0.1, 0.0,-0.2, 0.0, -0.1,  -0.1, 0.0, //State 0
                //                                 -0.1, -0.1, 0.0, -0.4, 0.0, -1.2, -0.1, 0.0, //State 1
                //                                 0.0, -0.8, 0.0,-0.2, -0.1, 0.0,  0.0, 0.0, //State 2
                //                                 0.0,-0.1,-0.1,-2.0, 0.0,-1.8,  0.0, 0.0, //State 3
                //                                 0.0, -0.1, 0.0,-0.2, 0.0, -0.1, 10.0, 0.0, //State 4
                //                                 -0.1, 0.0,-0.1,-0.1,-0.2, 0.0,  -0.1, -2.0};//State 5



                double[] rewards = new double[] {-0.1, -0.1, -0.1,  0.1, -0.1, -0.1, -0.1, -0.1, //State 0
                                                 -0.1, -0.1, -0.1, -0.1, -0.1, -0.1,  0.1, -0.1, //State 1
                                                 -0.1, -0.1,  0.1, -0.1, -0.1, -0.1, -0.1, -0.1, //State 2
                                                 -0.1, -0.1, -0.1,  0.1, -0.1, -0.1, -0.1, -0.1, //State 3
                                                 -0.1, -0.1,  0.1, -0.1, -0.1, -0.1, -0.1, -0.1, //State 4
                                                 -0.1, -0.1, -0.1, -0.1, -0.1, -0.1,  2.0, -0.1}; //State 5

                long[] transitions = new long[] {  1,   2,   2,   4,   0,   0,    1,   3,  //State 0
                                                   0,   2,   1,   1,   3,   0,    4,   2,  //State 1
                                                   1,   2,   4,   2,   0,   0,    0,   3,  //State 2
                                                   0,   2,   1,   4,   0,   1,    2,   3,  //State 3
                                                   3,   0,   5,   2,   0,   2,    4,   1,  //State 4
                                                   1,   4,   2,   2,   0,   0,   -1,   3}; //State 5
                int states = 6;
                int actions = 8;

                var res = reinforcementLearning.Run(qsim, new QArray<double>(rewards), new QArray<long>(transitions), states, actions).Result;

                DateTime stop = DateTime.Now;
                System.Console.WriteLine($"{stop-start}");
            }

            System.Console.WriteLine("Press any key to continue...");
            Console.ReadKey();
            
        }
    }
}