import numpy as np
import random
import pickle

stimuliDir = 'stimuli'

class BalancedSampler:
    def __init__(self, values):
        """Initialize with a list of possible values."""
        self.values = values[:]  # Store original values
        self.pool = []  # This will hold the shuffled values
        self._refill()  # Fill the pool initially
    
    def _refill(self):
        """Refills the pool by shuffling and resetting it."""
        self.pool = self.values[:]  # Copy original values
        random.shuffle(self.pool)  # Shuffle for randomness

    def pop(self):
        """Returns and removes a random value from the pool, refilling if empty."""
        if not self.pool:
            self._refill()
        return self.pool.pop()


# Parameters
num_of_bars = 9
gap_between_1st_and_2nd = 10
gap_between_the_two_highest = 10
min_bar_height = 15
highest_bar_values = [10*n for n in range(6, 10)] # size = 5]
total_stimuli_number = 80

def createBarChartArray(highest, maxIndex, volume = 0, gap_between_1st_and_2nd = gap_between_1st_and_2nd):
	second_highest = highest - gap_between_1st_and_2nd
	if volume == 0:
		arr = [second_highest] + random.sample(range(min_bar_height, second_highest), num_of_bars-1)
		while arr[maxIndex] == second_highest:
			random.shuffle(arr)
		arr[maxIndex] = highest
	else:
		volume -= (highest + second_highest)
		arr = [volume/(num_of_bars-2) for i in range(num_of_bars-2)]
		if volume/(num_of_bars-2) - min_bar_height > second_highest - volume/(num_of_bars-2):
			threshold = second_highest - volume/(num_of_bars-2)
		else:
			threshold = volume/(num_of_bars-2) - min_bar_height
		for i in range(len(arr)//2):
			deviance = random.random() * threshold
			arr[i] += deviance
			arr[-(i+1)] -= deviance
		random.shuffle(arr)
		pos_of_second_highest = random.randint(0,len(arr)-1)
		arr.insert(pos_of_second_highest, second_highest)
		arr.insert(maxIndex, highest)
	return arr

maxIndexPairs = []
for i in range(1, num_of_bars-1):
	for j in range(1, num_of_bars-1):
		if i != j:
			maxIndexPairs.append([i, j])

# set up the samplers for even distribution of condition values
maxIndexPairSampler = BalancedSampler(maxIndexPairs)
highestBarSampler = BalancedSampler(highest_bar_values)
highestBar2Samplers = {}
# for val in highest_bar_values:
# 	highestBar2Samplers[val] = BalancedSampler(list(range(max(val-40, 30), val, 10)))

stimuli = []
compare_index_answer_count = 0
for i in range(total_stimuli_number):
	highest = highestBarSampler.pop()
	maxIndexPair = maxIndexPairSampler.pop()

	highest2 = highest - gap_between_the_two_highest
	arr2 = createBarChartArray(highest2, maxIndexPair[1])
	volume = sum(arr2)
	arr1 = createBarChartArray(highest, maxIndexPair[0], volume = volume)
	# highest2 = highestBar2Samplers[highest].pop()

	# later is the answer for "compare_index" task
	assert(maxIndexPair[0] != maxIndexPair[1])
	if maxIndexPair[0] > maxIndexPair[1]: 
		ans2 = 1
	else:
		ans2 = 2
		compare_index_answer_count += 1

	stimuli.append([arr1, arr2, 1, ans2])
	# flipping order should happen at the backend

	# this stat indicates the probability that (answer for 1st task == answer for 2nd task)
	# brute-force generation until 0.5 is attained. 
	print("compare_index answer distribution: ", compare_index_answer_count/total_stimuli_number)

with open(stimuliDir + '/practice.pickle', 'wb') as file:
    pickle.dump(stimuli, file)

# validation check stimuli
validation_stimuli_compare_height = []

fifteens = [15 + (random.random()*2 - 1) for n in range(num_of_bars - 1)]
validationArr2 = [15 + (random.random()*2 - 1) for n in range(num_of_bars)]
for i in range(len(fifteens)+1):
	validationArr1 = fifteens[:]
	validationArr1.insert(i, 90)
	validation_stimuli_compare_height.append([validationArr1, validationArr2, 1])
	validation_stimuli_compare_height.append([validationArr2, validationArr1, 2])
	if i == 0:
		validation_stimuli_compare_height.append([validationArr1, validationArr2, 1, 0])
		validation_stimuli_compare_height.append([validationArr2, validationArr1, 2, 0])

validation_stimuli_compare_index = []

for i in range(10):
	validationArr1 = [15 + (random.random()*2 - 1) for n in range(num_of_bars - 1)]
	validationArr1.insert(7, 90 - 10 * (i%4))
	validationArr2 = [15 + (random.random()*2 - 1) for n in range(num_of_bars - 1)]
	validationArr2.insert(2, 90 - 10 * (i%4))
	validation_stimuli_compare_index.append([validationArr1, validationArr2, 0, 1])
	validation_stimuli_compare_index.append([validationArr2, validationArr1, 0, 2])

print("lengths of validation stimuli: ", len(validation_stimuli_compare_height), len(validation_stimuli_compare_index))

with open(stimuliDir + '/validation_stimuli_compare_height.pickle', 'wb') as file:
    pickle.dump(validation_stimuli_compare_height, file)
with open(stimuliDir + '/validation_stimuli_compare_index.pickle', 'wb') as file:
    pickle.dump(validation_stimuli_compare_index, file)

# easy practice stimuli
practice_stimuli_compare_height = []
for n in range(20):
	i = random.randint(1, num_of_bars-2)
	while True:
		j = random.randint(1, num_of_bars-2)
		if i != j:
			break
	practiceArr1 = createBarChartArray(90, i, gap_between_1st_and_2nd=30 + random.randint(0, 2)*10)
	practiceArr2 = createBarChartArray(40 + random.randint(0, 2)*10, j, gap_between_1st_and_2nd=10)
	if n % 2 == 0:
		practice_stimuli_compare_height.append([practiceArr1, practiceArr2, 1])
	else:
		practice_stimuli_compare_height.append([practiceArr2, practiceArr1, 2])

practice_stimuli_compare_index = []
for n in range(5):
	for i in range(1, 3):
		for j in range(num_of_bars-3, num_of_bars-1):
			highest = 70 + random.randint(0,2)*10
			practiceArr1 = createBarChartArray(highest, i, gap_between_1st_and_2nd = 30 + random.randint(0, 1)*10)
			practiceArr2 = createBarChartArray(highest, j, gap_between_1st_and_2nd = 30 + random.randint(0, 1)*10)
			if random.random() < 0.5:
				practice_stimuli_compare_index.append([practiceArr1, practiceArr2, 2])
			else:
				practice_stimuli_compare_index.append([practiceArr2, practiceArr1, 1])



print("lengths of practice stimuli: ", len(practice_stimuli_compare_height), len(practice_stimuli_compare_index))

with open(stimuliDir + '/practice_stimuli_compare_height.pickle', 'wb') as file:
    pickle.dump(practice_stimuli_compare_height, file)
with open(stimuliDir + '/practice_stimuli_compare_index.pickle', 'wb') as file:
    pickle.dump(practice_stimuli_compare_index, file)