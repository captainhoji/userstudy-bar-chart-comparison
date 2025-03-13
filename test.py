import pickle
import numpy as np

# with open('stimuli_red/stimuli_easy.pickle', 'rb') as file:
#     stimuli = pickle.load(file)

# for i, s in enumerate(stimuli):
# 	if s[0][0] == 70:
# 		print(f'{i}: {s}')

indexes_shuffled = []
difficulty_levels = 3
stimuli_per_block = 27

arr = np.arange(stimuli_per_block*4)
split_arrays = np.split(arr, difficulty_levels ** 2)
for subarray in split_arrays:
    np.random.shuffle(subarray)
    indexes_shuffled.append(np.split(subarray, 4))
indexes_shuffled = [np.concatenate(group) for group in zip(*indexes_shuffled)]
for indexes_in_condition in indexes_shuffled:
    np.random.shuffle(indexes_in_condition)

for g in indexes_shuffled:
	print(g)