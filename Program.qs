namespace QRL_App {

    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Math;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Arithmetic;
    open Microsoft.Quantum.Measurement;
    open Microsoft.Quantum.Convert;
    open Microsoft.Quantum.Oracles;
    open Microsoft.Quantum.AmplitudeAmplification;
    open Microsoft.Quantum.Arrays;


    newtype qstateRestoring = (Qubit[] => Unit);
    newtype action_iteration = (Int, Double);
    


    operation Set (desired: Result, q1: Qubit) : Unit {
        if (desired != M(q1)) {
            X(q1);
        }
    }

    operation multiCNOT(ctrl: Qubit[], tgt: Qubit) : Unit {
        let qLength = Length(ctrl) - 1;

        //Use N-1 ancilla qubits (N = number of control qubits)
        using (anc = Qubit[qLength]){

            //Initialize ancilla registers
            for (i in 0..qLength-1) {
                Set(Zero, anc[i]);
            }

            //Apply multiple controlled NOT
            CCNOT(ctrl[0], ctrl[1], anc[0]);
            if (qLength > 1) {
                for (i in 0..qLength-2) {
                    CCNOT(anc[i], ctrl[i+2], anc[i+1]);
                }
            }
            
            //Set the result of the multiple controlled not in target qubit
            CNOT(anc[qLength-1], tgt);

            //Apply the inverse operation to leave the control qubits in its original states
            if (qLength > 1) {
                for (i in 0..qLength-2) {
                    CCNOT(anc[qLength-2-i], ctrl[qLength-i], anc[qLength-i-1]);
                }
            }
            CCNOT(ctrl[0], ctrl[1], anc[0]);

            //Leave ancilla registers in state 0
            for (i in 0..qLength-1) {
                Set(Zero, anc[i]);
            }
        }
    }

    operation Grover (action: Int, target: Qubit[], flagQubit: Qubit, groverIterations: Int) : Unit {

        let target_action = BoolArrayAsResultArray(IntAsBoolArray(action, Length(target))); //Action converted from Int to type Result[]

        for (i in 1..groverIterations) {
            //Uf: Amplifying target action probability
            groverOracle(target, flagQubit, action);

            //Hadamards
            ApplyToEachCA(H, target);

            //U0 orthogonal
            ApplyToEachCA(X, target);
            if (Length(target) > 1) {
                multiCNOT(target,flagQubit);
            }
            else {
                CNOT(target[0],flagQubit);
            }
            ApplyToEachCA(X, target);

            //Hadamards
            ApplyToEachCA(H, target);
        }
    }

    operation groverOracle (x: Qubit[], aux: Qubit, s: Int) : Unit {
        //State to be amplified
        let search = BoolArrayAsResultArray(IntAsBoolArray(s, Length(x)));

        //Amplification
        for (i in 0..Length(x)-1) {
            if (search[i] == Zero) {
                X(x[i]);
            }
        }

        if (Length(x) > 1) {
            multiCNOT (x, aux);
        }
        else {
            CNOT (x[0], aux);
        }

        for (i in 0..Length(x)-1) {
            if (search[i] == Zero) {
                X(x[i]);
            }
        }
       
    }

    operation DoNothing (q: Qubit[]) : Unit {

    }

    operation reinforcementLearning (rewards: Double[], transitions: Int[], numStates: Int, numActions: Int) : Unit {

        //---------------------ALGORITHM PARAMETERS----------------------
        //Parameter alpha (learning rate) with its decreasing rate, parameter gamma (discount factor for the value of the transited state V(s'))
        mutable alpha = 0.07;
        let decreasing_alpha = 0.01;
        let gamma = 0.99;

        //Constant k for the state value scaling and minimum error convergence
        let k = 0.7;
        let error = 0.004;
        //-----------------------------------------------------------------


        //n where 2^n is the number of actions
        let actionSpace = Floor(Lg(IntAsDouble(numActions)));

        //Accumulated action values/iterations
        mutable amp_iterations = new Double[numStates*numActions];

        //Stepsize that determines the maximum number of iterations according to Grover Search
        let stepsize = ArcSin(1.0/(Sqrt(IntAsDouble(numActions))));
        let max_it = IntAsDouble(Round(PI()/(4.0*stepsize)-0.5));

        //Counter for the episodes and one index for the ancilla qubit(always 0)
        mutable countEpisodes = 0;
        let idxQubit = 0;


        //Use s*log2(a) + 1 to encode all action space for each state plus one ancilla qubit which will be used for the AA algorithm
        //(s = number of different states, a = number of different actions)
        using (qregister = Qubit[numStates*actionSpace + 1]) {
            
            //Take the ancilla qubit used for AA apart from the actions, initialize the state values register (to 0) and the stop condition
            let flagQubit = qregister[idxQubit];
            let actions = Exclude([idxQubit], qregister);
            mutable state_values = new Double[numStates];
            mutable stop = true;

            Message($">>>>> TOTAL QUBITS: {Length(actions) + 1}");

            //Initialize all action qubits in equal superposition
            ApplyToEachCA(H, actions);

            //Repeat until the convergence is reached
            repeat {

                //Next episode starts
                set countEpisodes += 1;
                Message($"Episode number {countEpisodes}");


                //Collapses one action for all existing states
                let selected_actions = MultiM(actions);

                //Set all action qubits to its initial state
                ResetAll(actions); //Reset to Zero state
                ApplyToEachCA(H, actions); //Set uniform superposition

                //Set stop condition again to true
                set stop = true;

                //FOR ALL STATES: Calculate grover iterations, update global value, apply action amplification(Grover)
                for (i in 0..numStates-1) {
                    //First and last qubits corresponding to the related set of actions for each state
                    let start = i*actionSpace;
                    let end = start+actionSpace-1;

                    //Save the total summation of all the action iteration values to perform the proportion for the amplifying
                    mutable total_sum = 0.0;

                    //Conversion of the action measured to integer
                    let decimal_action = ResultArrayAsInt(selected_actions[start..end]);

                    //Index of the corresponding action of one state to look up its reward and its AA iterations
                    let action_idx = i*numActions + decimal_action;

                    //Transition the action generates when it is chosen
                    mutable trans_state = transitions [i*numActions + decimal_action];

                    //Save latest state value to compare it to the new one
                    let prev_state_val = state_values[i];

                    //Reached the final state --------------------------------------------------
                    if (trans_state == -1) {
                        set trans_state = i;
                    }

                    
                    //Set the times L = min {int(k*(r+V(s)), int((pi/4Th)-1/2)} the probability of the measured action will be amplified
                    set amp_iterations w/=(action_idx) <- MaxD(0.0, (k * (rewards[action_idx] + state_values[trans_state])));

                    //Update the state value of the corresponding state with the updating function V(s) = V(s) + alpha*(reward + gamma*V(s') - V(s))
                    set state_values w/=i <- state_values[i] + alpha*(rewards[action_idx] + gamma*state_values[trans_state] - state_values[i]);
                    

                    for (j in 0..numActions-1) {
                        set total_sum += amp_iterations[i*numActions + j];
                    }


                    //Print the different property values of the action measured: Encoding qubits, iterations, the new state value of the whole state, the action and the transition to the new state
                    Message($">>>>> STATE {i}: Qubits {start} to {end}; State value {state_values[i]}; Action {decimal_action}; Trans: {trans_state}");


                    //Convergency condition: when all state values are equal than previous ones
                    if (stop and AbsD(prev_state_val - state_values[i]) > error) {
                        set stop = false;
                    }


                    //Restore initial state of the ancilla qubit used for amplitude amplification
                    Set(Zero, flagQubit);
                    H(flagQubit);
                    Z(flagQubit);

                    
                    
                    //Restore the quantum state of each action belonging to each state after the measurement
                    for (j in 0..numActions-1) {
                        if (total_sum > max_it) {
                            Grover(j, actions[start..end], flagQubit, Round(max_it * (amp_iterations[i*numActions + j]/total_sum)));
                        }
                        else {
                            Grover(j, actions[start..end], flagQubit, Round(amp_iterations[i*numActions + j]));
                        }
                    }
                }

                //Every 5 episodes, the program prints the amplitude amplification iterations of each action in each state & decreases the learning rate(alpha)
                if (countEpisodes % 10 == 0) {

                    Message($"AMP ITERATIONS:");

                    for (i in 0..numStates-1) {
                        Message($"STATE {i}: ");

                        for (j in 0..numActions-1) {
                            Message($"Action {j}: {amp_iterations[i*numActions+j]}");
                        }
                        Message($"");
                    }

                    if (alpha > 0.0) {
                        set alpha -= decreasing_alpha;
                    }
                    Message($"New alpha = {alpha}");
                }
                
            } until (stop);

            Message($"Number of episodes: {countEpisodes}");
            ResetAll(qregister);
        }

    }

}

