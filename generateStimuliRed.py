import numpy as np
import random
import pickle

stimuliDir = 'stimuli_red'

num_of_bars = 12
min_bar_height = 15
max_bar_height = 100 - min_bar_height
total_stimuli_number = 80

def main():

	stimuli_per_condition = 12 # 27 per condition

	deltas_height = [5, 10, 20]
	deltas_index = [1, 2, 4]
	# real task
	stimuli = []
	for dh in deltas_height:
		for di in deltas_index:
			stimuli.extend(generateTaskStimuli(stimuli_per_condition, delta_height = dh, delta_index = di))

	print("length of stimuli: ", len(stimuli))

	with open(stimuliDir + '/stimuli.pickle', 'wb') as file:
	    pickle.dump(stimuli, file)

	# engagement checks
	# validation_per_condition = 20
	# validation_stimuli_compare_height = generateTaskStimuli(validation_per_condition, delta_height = 50, delta_index = 0)
	# validation_stimuli_compare_index = generateTaskStimuli(validation_per_condition, delta_height = 0, delta_index = 7)

	# with open(stimuliDir + '/validation_stimuli_compare_height.pickle', 'wb') as file:
	#     pickle.dump(validation_stimuli_compare_height, file)
	# with open(stimuliDir + '/validation_stimuli_compare_index.pickle', 'wb') as file:
	#     pickle.dump(validation_stimuli_compare_index, file)

	# hard practice
	stimuli_practice = []
	for dh in deltas_height:
		for di in deltas_index:
			stimuli_practice.extend(generateTaskStimuli(stimuli_per_condition, delta_height = dh, delta_index = di))

	with open(stimuliDir + '/practice.pickle', 'wb') as file:
	    pickle.dump(stimuli_practice, file)

	# easy practice
	stimuli_easy = generateTaskStimuli(stimuli_per_condition*4, delta_height = 30, delta_index = 5)
	with open(stimuliDir + '/stimuli_easy.pickle', 'wb') as file:
	    pickle.dump(stimuli_easy, file)

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


def createBarChartArray(red, redIndex, volume = 0):
	if volume == 0:
		bars = random.sample(range(min_bar_height, max_bar_height+1), num_of_bars-1)
	else:
		bars = []
		remaining_volume = volume - red
		for i in range(num_of_bars - 2):
			# Calculate the valid range for this bar
			min_possible = max(min_bar_height, remaining_volume - (num_of_bars - 1 - (i + 1)) * max_bar_height)
			max_possible = min(max_bar_height, remaining_volume - (num_of_bars - 1 - (i + 1)) * min_bar_height)

			# Sample within the valid range
			bar = np.random.uniform(min_possible, max_possible)
			bars.append(bar)
			remaining_volume -= bar

		# Assign the last bar to exactly match the remaining volume
		bars.append(remaining_volume)

	random.shuffle(bars)
	bars.insert(redIndex, red)
	return bars

def generateTaskStimuli(n, delta_height, delta_index):
	redIndexPairs = list([[i, i+delta_index] for i in range(2, num_of_bars - 2 - delta_index)])
	redIndexPairs.extend([[b, a] for a, b in redIndexPairs])
	redIndexPairSampler = BalancedSampler(redIndexPairs)
	redBarValues = [5*i for i in range((min_bar_height+delta_height)//5, max_bar_height//5 + 1)]
	redBarSampler = BalancedSampler(redBarValues)

	while True:
		stimuli = []
		compare_index_answer_count = 0
		for i in range(n):
			higherRed = redBarSampler.pop()
			lowerRed = higherRed - delta_height
			redIndexPair = redIndexPairSampler.pop()

			arr1 = createBarChartArray(higherRed, redIndexPair[0])
			arr2 = createBarChartArray(lowerRed, redIndexPair[1], volume = sum(arr1))

			# later is the answer for "compare_index" task
			if redIndexPair[0] > redIndexPair[1]: 
				ans2 = 1
			else:
				ans2 = 2
				compare_index_answer_count += 1

			stimuli.append([arr1, arr2, 1, ans2, redIndexPair[:]])
			# flipping order should happen at the backend

		# this stat indicates the probability that (answer for 1st task == answer for 2nd task)
		# brute-force generation until 0.5 is attained. 
		if compare_index_answer_count == len(stimuli) // 2:
			ratio = compare_index_answer_count/len(stimuli)
			print("compare_index answer distribution: ", ratio)
			break
	return stimuli

if __name__=="__main__":
    main()


