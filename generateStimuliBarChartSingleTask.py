# Stimuli for two-phase task where the user finds the tallest/shortest bar from each chart and compare their darkness

import numpy as np
import random
import pickle
from itertools import product
from collections import Counter
from dataclasses import dataclass

@dataclass
class StimuliConfig:
	darkest_side: int
	lightest_side: int
	longest_side: int
	shortest_side: int
	delta_length: float
	num_of_bars: int
	min_bar_length: float = 20
	max_bar_length: float = 80
	delta_brightness: int = 1

num_of_bars = 10

stimuliDir = 'stimuli_bias/single-task'

def main():
	# delta_height, delta_index, delta_length
	deltas = [[0.1, 1], [0.2, 2]]
	all_combinations = list(product([1, 2], repeat=4))

	# real task
	stimuli = [
		generateTaskStimuli(StimuliConfig(
			darkest_side=combo[0],
			lightest_side=combo[1],
			longest_side=combo[2],
			shortest_side=combo[3],
			delta_length=delta[0],
			num_of_bars=num_of_bars,
			delta_brightness = delta[1]
		))
		for combo in all_combinations
		for delta in deltas
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
			darkest_side=combo[0],
			lightest_side=combo[1],
			longest_side=combo[2],
			shortest_side=combo[3],
			delta_length=0.5,
			delta_brightness=3,
			num_of_bars=num_of_bars,
			min_bar_length=20,
			max_bar_length=80
		))
		for combo in all_combinations
	]

	with open(stimuliDir + '/validation_stimuli.pickle', 'wb') as file:
	    pickle.dump(validation_stimuli, file)

	# hard practice
	stimuli_practice = [
		generateTaskStimuli(StimuliConfig(
			darkest_side=combo[0],
			lightest_side=combo[1],
			longest_side=combo[2],
			shortest_side=combo[3],
			delta_length=delta[0],
			num_of_bars=num_of_bars,
			delta_brightness = delta[1]
		))
		for combo in all_combinations
		for delta in deltas
	]

	with open(stimuliDir + '/practice.pickle', 'wb') as file:
	    pickle.dump(stimuli_practice, file)

	# easy practice
	stimuli_easy = [
		generateTaskStimuli(StimuliConfig(
			darkest_side=combo[0],
			lightest_side=combo[1],
			longest_side=combo[2],
			shortest_side=combo[3],
			delta_length=0.3,
			delta_brightness=2,
			num_of_bars=num_of_bars,
			min_bar_length=20,
			max_bar_length=80
		))
		for i in range(2)
		for combo in all_combinations
	]

	with open(stimuliDir + '/stimuli_easy.pickle', 'wb') as file:
	    pickle.dump(stimuli_easy, file)

def createBarChartArray(longest_bar_length, longest_bar_index, shortest_bar_length, shortest_bar_index, config: StimuliConfig):
	bar_lengths = np.random.uniform(low = shortest_bar_length / (1-config.delta_length), high = longest_bar_length * (1-config.delta_length), size = config.num_of_bars-1)
	random.shuffle(bar_lengths)
	bar_lengths = list(bar_lengths)

	# make sure the insertions are made from the smallest to largest index
	if longest_bar_index < shortest_bar_index:
		bar_lengths.insert(longest_bar_index, longest_bar_length)
		bar_lengths.insert(shortest_bar_index, shortest_bar_length)
	else:
		bar_lengths.insert(shortest_bar_index, shortest_bar_length)
		bar_lengths.insert(longest_bar_index, longest_bar_length)

	bars = [[0, length] for length in bar_lengths]
	return bars

def generateTaskStimuli(config: StimuliConfig):
	while True:
		longest_bar_length = random.uniform((2 * config.max_bar_length + config.min_bar_length) / 3, config.max_bar_length)
		second_longest_bar_length = longest_bar_length * (1-config.delta_length)
		shortest_bar_length = random.uniform(config.min_bar_length, (config.max_bar_length + 2 * config.min_bar_length) / 3)
		second_shortest_bar_length = shortest_bar_length / (1-config.delta_length)

		indexes_extrema_arr1 = random.sample(range(1, config.num_of_bars - 1), 2)
		indexes_extrema_arr2 = random.sample(range(1, config.num_of_bars - 1), 2)

		if config.longest_side == 1:
			arr1_longest_length = longest_bar_length
			arr2_longest_length = second_longest_bar_length
		else:
			arr1_longest_length = second_longest_bar_length
			arr2_longest_length = longest_bar_length

		if config.shortest_side == 1:
			arr1_shortest_length = shortest_bar_length
			arr2_shortest_length = second_shortest_bar_length
		else:
			arr1_shortest_length = second_shortest_bar_length
			arr2_shortest_length = shortest_bar_length

		arr1 = createBarChartArray(arr1_longest_length, indexes_extrema_arr1[0], arr1_shortest_length, indexes_extrema_arr1[1], config)
		arr2 = createBarChartArray(arr2_longest_length, indexes_extrema_arr2[0], arr2_shortest_length, indexes_extrema_arr2[1], config)

		# sanity check: all bars should be within the range [min_bar_length, max_bar_length]
		omg = False
		for bar in arr1:
			if config.min_bar_length > (bar[1]-bar[0]) or (bar[1]-bar[0]) > config.max_bar_length:
				print(bar[1]-bar[0])
				omg = True
				break
		for bar in arr2:
			if config.min_bar_length > (bar[1]-bar[0]) or (bar[1]-bar[0]) > config.max_bar_length:
				print(bar[1]-bar[0])
				omg = True
				break
		if not omg:
			break

	# for output purposes so that front end does not need to calcualte which bars are the longest/shortest
	indexes_longest = [indexes_extrema_arr1[0], indexes_extrema_arr2[0]] # [longest bar of arr1, longest bar of arr2]
	indexes_shortest = [indexes_extrema_arr1[1], indexes_extrema_arr2[1]] # [shortest bar of arr1, shortest bar of arr2]

	indexes_extrema_arr1 = random.sample(range(1, config.num_of_bars - 1), 2)
	indexes_extrema_arr2 = random.sample(range(1, config.num_of_bars - 1), 2)
	indexes_darkest = [indexes_extrema_arr1[0], indexes_extrema_arr2[0]] # [darkest bar of arr1, darkest bar of arr2]
	indexes_lightest = [indexes_extrema_arr1[1], indexes_extrema_arr2[1]] # [lightest bar of arr1, lightest bar of arr2]

	if config.delta_brightness == 1:
		brightness_darkest = random.randint(5, 6)
		brightness_second_darkest = brightness_darkest - config.delta_brightness
		brightness_lightest = random.randint(0, 1)
		brightness_second_lightest = brightness_lightest + config.delta_brightness
	elif config.delta_brightness == 2:
		brightness_darkest, brightness_second_darkest, brightness_lightest, brightness_second_lightest = random.sample([[5,3,0,2],[6,4,0,2],[6,4,1,3]], 1)[0]
	elif config.delta_brightness == 3:
		brightness_darkest = 6
		brightness_second_darkest = 3
		brightness_second_lightest = 3
		brightness_lightest = 0

	print(brightness_second_lightest, brightness_second_darkest)
	
	for sublist in arr1: sublist.append(random.randint(brightness_second_lightest, brightness_second_darkest))
	for sublist in arr2: sublist.append(random.randint(brightness_second_lightest, brightness_second_darkest))

	if config.darkest_side == 1:
		arr1[indexes_darkest[0]][2] = brightness_darkest
		arr2[indexes_darkest[1]][2] = brightness_second_darkest
	else:
		arr1[indexes_darkest[0]][2] = brightness_second_darkest
		arr2[indexes_darkest[1]][2] = brightness_darkest

	if config.lightest_side == 1:
		arr1[indexes_lightest[0]][2] = brightness_lightest
		arr2[indexes_lightest[1]][2] = brightness_second_lightest
	else:
		arr1[indexes_lightest[0]][2] = brightness_second_lightest
		arr2[indexes_lightest[1]][2] = brightness_lightest

	index_longest = indexes_longest[config.longest_side-1]
	index_shortest = indexes_shortest[config.shortest_side-1]
	index_darkest = indexes_darkest[config.darkest_side-1]
	index_lightest = indexes_lightest[config.lightest_side-1]

	return [arr1, arr2, config.longest_side, config.shortest_side, config.darkest_side, config.lightest_side, index_longest, index_shortest, index_darkest, index_lightest]


if __name__=="__main__":
	main()


