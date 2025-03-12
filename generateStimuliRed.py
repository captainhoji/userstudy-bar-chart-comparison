import numpy as np
import random
import pickle

stimuliDir = 'stimuli_red'

num_of_bars = 12
gap_between_reds = 5
min_bar_height = 15
max_bar_height = 100 - min_bar_height
total_stimuli_number = 80
delta_index = 1

def main():
    # stimuli_height = generateHeightTaskStimuli(total_stimuli_number)	
	# with open(stimuliDir + '/stimuli_height.pickle', 'wb') as file:
	#     pickle.dump(stimuli_height, file)

	# stimuli_index = generateIndexTaskStimuli(total_stimuli_number)
	# with open(stimuliDir + '/stimuli_index.pickle', 'wb') as file:
	#     pickle.dump(stimuli_index, file)

	stimuli = generateTaskStimuli(total_stimuli_number)
	with open(stimuliDir + '/stimuli.pickle', 'wb') as file:
	    pickle.dump(stimuli, file)

	stimuli_practice = generateTaskStimuli(total_stimuli_number)
	with open(stimuliDir + '/practice.pickle', 'wb') as file:
	    pickle.dump(stimuli_practice, file)

	gap_between_reds = 15
	delta_index = 2

	stimuli_easy = generateIndexTaskStimuli(total_stimuli_number)
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
		arr = random.sample(range(min_bar_height, max_bar_height+1), num_of_bars-1)
	else:
		volume -= red
		arr = createBarChartArrayRec(volume, num_of_bars-1, minHeight=min_bar_height, maxHeight=max_bar_height)
	random.shuffle(arr)
	arr.insert(redIndex, red)
	return arr

def createBarChartArrayRec(volume, nBars, minHeight = 0, maxHeight = 100, arr = []):
	if nBars == 1:
		arr.append(volume)
		return arr
	while True:
		loc = volume/nBars
		bar = np.random.normal(loc=loc, scale=loc/2)
		if minHeight < bar and volume - (nBars-1) * maxHeight < bar and bar < volume - (nBars-1) * minHeight:
			break
	arr.append(bar)
	return createBarChartArrayRec(volume - bar, nBars-1, minHeight, maxHeight, arr)

def generateTaskStimuli(n):
	redIndexPairs = list([(i, i+delta_index) for i in range(2, num_of_bars - 2 - delta_index)])
	redIndexPairs.extend((b, a) for a, b in redIndexPairs)
	redIndexPairSampler = BalancedSampler(redIndexPairs)
	redBarValues = [5*i for i in range((min_bar_height+gap_between_reds)//5, max_bar_height//5 + 1)]
	redBarSampler = BalancedSampler(redBarValues)

	stimuli = []
	compare_index_answer_count = 0
	for i in range(n):
		higherRed = redBarSampler.pop()
		lowerRed = higherRed - gap_between_reds
		redIndexPair = redIndexPairSampler.pop()

		arr1 = createBarChartArray(higherRed, redIndexPair[0])
		arr2 = createBarChartArray(lowerRed, redIndexPair[1], volume = sum(arr1))

		# later is the answer for "compare_index" task
		if redIndexPair[0] > redIndexPair[1]: 
			ans2 = 1
		else:
			ans2 = 2
			compare_index_answer_count += 1

		stimuli.append([arr1, arr2, 1, ans2, redIndexPair])
		# flipping order should happen at the backend

		# this stat indicates the probability that (answer for 1st task == answer for 2nd task)
		# brute-force generation until 0.5 is attained. 
		print("compare_index answer distribution: ", compare_index_answer_count/total_stimuli_number)

	return stimuli

if __name__=="__main__":
    main()


