import pickle
import numpy as np

with open('stimuli_bias/stimuli_easy.pickle', 'rb') as file:
    stimuli = pickle.load(file)

for i in range(len(stimuli)):
    print(f'{i}: {stimuli[i][2:]}\n')