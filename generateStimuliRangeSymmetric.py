import numpy as np
import random
import pickle
from itertools import product
from collections import Counter
from dataclasses import dataclass

@dataclass
class StimuliConfig:
	higherBar: int
	laterBar: int
	longerBar: int
	darkerBar: int
	delta_height: int
	delta_index: int
	delta_length: float
	num_of_bars: int
	min_bar_height: float
	max_bar_height: float
	min_edge_gap: float
	delta_darkness: int = 1
	darkest_salience: int = 2
	darkest_variance: int = 1

min_bar_height = 20
max_bar_height = 70
min_edge_gap = 5

stimuliDir = 'stimuli_range'

num_of_bars = 10


def main():
	# delta_height, delta_index, delta_length
	difficulty_levels = [[10, 2, .1], [20, 3, .2]]
	all_combinations = list(product([1, 2], repeat=4))

	# real task
	stimuli = [
		generateTaskStimuli(StimuliConfig(
			higherBar=combo[0],
			laterBar=combo[1],
			longerBar=combo[2],
			darkerBar=combo[3],
			delta_height=deltas[0],
			delta_index=deltas[1],
			delta_length=deltas[2],
			num_of_bars=num_of_bars,
			min_bar_height=min_bar_height,
			max_bar_height=max_bar_height,
			min_edge_gap=min_edge_gap
		))
		for i in range(4)
		for combo in all_combinations
		for deltas in difficulty_levels
	]

	# Ensure all condition combinations have balanced distribution
	counter = Counter(map(lambda x: tuple(x[2:6]), stimuli))
	counts = [counter[combo] for combo in all_combinations]
	for combo in all_combinations:
		print(f"{combo}: {counter[combo]}")

	print(f"Generated stimuli of length {len(stimuli)}")
	with open(stimuliDir + '/stimuli.pickle', 'wb') as file:
	    pickle.dump(stimuli, file)

	# engagement checks
	validation_stimuli = [
		generateTaskStimuli(StimuliConfig(
			higherBar=combo[0],
			laterBar=combo[1],
			longerBar=combo[2],
			darkerBar=combo[3],
			delta_height=30,
			delta_index=5,
			delta_length=.40,
			num_of_bars=num_of_bars,
			min_bar_height=20,
			max_bar_height=70,
			min_edge_gap=0,
			delta_darkness=0,
			darkest_salience=3,
			darkest_variance=0
		))
		for combo in all_combinations
	]

	with open(stimuliDir + '/validation_stimuli.pickle', 'wb') as file:
	    pickle.dump(validation_stimuli, file)

	# hard practice
	stimuli_practice = [
		generateTaskStimuli(StimuliConfig(
			higherBar=combo[0],
			laterBar=combo[1],
			longerBar=combo[2],
			darkerBar=combo[3],
			delta_height=deltas[0],
			delta_index=deltas[1],
			delta_length=deltas[2],
			num_of_bars=num_of_bars,
			min_bar_height=min_bar_height,
			max_bar_height=max_bar_height,
			min_edge_gap=min_edge_gap
		))
		for i in range(4)
		for combo in all_combinations
		for deltas in difficulty_levels
	]

	with open(stimuliDir + '/practice.pickle', 'wb') as file:
	    pickle.dump(stimuli_practice, file)

	# easy practice
	stimuli_easy = [
		generateTaskStimuli(StimuliConfig(
			higherBar=combo[0],
			laterBar=combo[1],
			longerBar=combo[2],
			darkerBar=combo[3],
			delta_height=25,
			delta_index=4,
			delta_length=.25,
			num_of_bars=num_of_bars,
			min_bar_height=20,
			max_bar_height=60,
			min_edge_gap=2.5
		))
		for i in range(4)
		for combo in all_combinations
	]

	with open(stimuliDir + '/stimuli_easy.pickle', 'wb') as file:
	    pickle.dump(stimuli_easy, file)

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

def generateTaskStimuli(config: StimuliConfig):
	higherRed = random.uniform(min_bar_height + config.delta_height, max_bar_height)
	lowerRed = higherRed * (1 - config.delta_length)

	if config.num_of_bars - 3 - config.delta_index < 2:
		raise ValueError("Not enough bars for the required delta_index.")
	redIndex = random.randint(2, config.num_of_bars - 3 - config.delta_index)
	redIndexPair = [redIndex, redIndex + config.delta_index]

	if config.longerBar == 2:
		config.laterBar = 3 - config.laterBar
		config.higherBar = 3 - config.higherBar
		config.darkerBar = 3 - config.darkerBar

	if config.laterBar == 1:
		redIndexPair.reverse()
	
	arr1 = createBarChartArray(higherRed, redIndexPair[0])
	arr2 = createBarChartArray(lowerRed, redIndexPair[1], volume = sum(arr1)) # Ensure total volume matches first chart


	# "lift" all the bars from the axis
	# controlling the answer for the "highest top" task
	# arr1 and arr2 transformed from a list of integers to a list of [floor, length]s
	if config.higherBar == 1:
		for j in range(len(arr1)):
			if j == redIndexPair[0]: # Note: arr1[j] == higherRed
				floor = random.uniform(max(config.min_edge_gap, config.min_edge_gap - higherRed + lowerRed + config.delta_height), 100 - higherRed - config.min_edge_gap)
				arr1[j] = [floor, higherRed]
				assert(floor+higherRed <= 100-config.min_edge_gap), f'{higherRed}, {lowerRed}, {config.delta_height}, {arr1[j]}'
			else:
				arr1[j] = [random.uniform(config.min_edge_gap, 100-config.min_edge_gap-arr1[j]), arr1[j]]
		for j in range(len(arr2)):
			if j == redIndexPair[1]:
				ceil = sum(arr1[redIndexPair[0]])-config.delta_height
				arr2[j] = [ceil - lowerRed, lowerRed]
				assert(arr2[j][0] >= config.min_edge_gap and arr2[j][0]+arr2[j][1] <= 100-config.min_edge_gap), f"bar lengths: {higherRed}, {lowerRed}\ndelta_height: {config.delta_height}\n{arr1[redIndexPair[0]]}, {arr2[j]}"
			else:
				arr2[j] = [random.uniform(config.min_edge_gap, 100-config.min_edge_gap-arr2[j]), arr2[j]]
	else:					
		for j in range(len(arr2)):
			if j == redIndexPair[1]: # arr2[j] == lowerRed
				floor = random.uniform(config.min_edge_gap + higherRed - lowerRed + config.delta_height, 100 - lowerRed - config.min_edge_gap)
				arr2[j] = [floor, lowerRed]
				assert(floor+lowerRed <= 100-config.min_edge_gap), f'{arr2[j]}'
			else:
				arr2[j] = [random.uniform(config.min_edge_gap, 100-config.min_edge_gap-arr2[j]), arr2[j]]
		for j in range(len(arr1)):
			if j == redIndexPair[0]:
				ceil = sum(arr2[redIndexPair[1]])-config.delta_height
				arr1[j] = [ceil - higherRed, higherRed]
				assert(arr1[j][0] >= config.min_edge_gap and arr1[j][0]+arr1[j][1] <= 100-config.min_edge_gap), f"bar lengths: {higherRed}, {lowerRed}\ndelta_height: {config.delta_height}\n{arr1[j]}, {arr2[redIndexPair[0]]}"
			else:
				arr1[j] = [random.uniform(config.min_edge_gap, 100-config.min_edge_gap-arr1[j]), arr1[j]]

	highlightColor1 = random.randint(7-config.darkest_variance, 7)
	highlightColor2 = highlightColor1 - config.delta_darkness
	if config.darkerBar == 1:
		for sublist in arr1:
			sublist.append(random.randint(1, highlightColor1 - config.darkest_salience))
		arr1[redIndexPair[0]][2] = highlightColor1
		for sublist in arr2:
			sublist.append(random.randint(1, highlightColor2 - config.darkest_salience))
		arr2[redIndexPair[1]][2] = highlightColor2
	else:
		for sublist in arr2:
			sublist.append(random.randint(1, highlightColor1 - config.darkest_salience))
		arr2[redIndexPair[1]][2] = highlightColor1
		for sublist in arr1:
			sublist.append(random.randint(1, highlightColor2 - config.darkest_salience))
		arr1[redIndexPair[0]][2] = highlightColor2

	if config.longerBar == 2:
		arr1, arr2 = arr2, arr1
		redIndexPair[0], redIndexPair[1] = redIndexPair[1], redIndexPair[0]
		config.laterBar = 3 - config.laterBar
		config.higherBar = 3 - config.higherBar
		config.darkerBar = 3 - config.darkerBar

	return [arr1, arr2, config.longerBar, config.laterBar, config.higherBar, config.darkerBar, redIndexPair[:]]


if __name__=="__main__":
	main()


