# Stimuli for two-phase task where the user finds the tallest/shortest bar from each chart and compare their darkness

import numpy as np
import random
import pickle
from itertools import product
from collections import Counter
from dataclasses import dataclass

@dataclass
class StimuliConfig:
	longest_darker_side: int
	longest_longer_side: int
	shortest_darker_side: int
	shortest_longer_side: int
	delta_length: float
	num_of_bars: int
	min_bar_length: float = 10
	max_bar_length: float = 90
	delta_brightness: int = 1

num_of_bars = 10

stimuliDir = 'stimuli_bias/length-color'

def main():
	# delta_height, delta_index, delta_length
	deltas = [1, 2]
	all_combinations = list(product([1, 2], repeat=4))

	# real task
	stimuli = [
		generateTaskStimuli(StimuliConfig(
			longest_darker_side=combo[0],
			longest_longer_side=combo[1],
			shortest_darker_side=combo[2],
			shortest_longer_side=combo[3],
			delta_length=0.1,
			num_of_bars=num_of_bars,
			delta_brightness = delta
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
			longest_darker_side=combo[0],
			longest_longer_side=combo[1],
			shortest_darker_side=combo[2],
			shortest_longer_side=combo[3],
			delta_length=0,
			delta_brightness=5,
			num_of_bars=num_of_bars,
			min_bar_length=10,
			max_bar_length=90
		))
		for combo in all_combinations
	]

	with open(stimuliDir + '/validation_stimuli.pickle', 'wb') as file:
	    pickle.dump(validation_stimuli, file)

	# hard practice
	stimuli_practice = [
		generateTaskStimuli(StimuliConfig(
			longest_darker_side=combo[0],
			longest_longer_side=combo[1],
			shortest_darker_side=combo[2],
			shortest_longer_side=combo[3],
			delta_length=0.1,
			num_of_bars=num_of_bars,
			delta_brightness = delta
		))
		for combo in all_combinations
		for delta in deltas
	]

	with open(stimuliDir + '/practice.pickle', 'wb') as file:
	    pickle.dump(stimuli_practice, file)

	# easy practice
	stimuli_easy = [
		generateTaskStimuli(StimuliConfig(
			longest_darker_side=combo[0],
			longest_longer_side=combo[1],
			shortest_darker_side=combo[2],
			shortest_longer_side=combo[3],
			delta_length=0.15,
			delta_brightness=3,
			num_of_bars=num_of_bars,
			min_bar_length=10,
			max_bar_length=90
		))
		for i in range(2)
		for combo in all_combinations
	]

	with open(stimuliDir + '/stimuli_easy.pickle', 'wb') as file:
	    pickle.dump(stimuli_easy, file)

def createBarChartArray(longest_bar_length, longest_bar_index, shortest_bar_length, shortest_bar_index, config: StimuliConfig):
	low = shortest_bar_length / (1-config.delta_length)
	high = longest_bar_length * (1-config.delta_length)
	if config.delta_length == 0:
		low = 45
		high = 55
	bar_lengths = np.random.uniform(low = low, high = high, size = config.num_of_bars-1)
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
		if config.delta_length == 0: # for engagement checks
			longest_bar_length = 90
			second_longest_bar_length = 90
			shortest_bar_length = 10
			second_shortest_bar_length = 10
		else:
			longest_bar_length = random.uniform(70, config.max_bar_length)
			second_longest_bar_length = longest_bar_length * (1-config.delta_length)
			shortest_bar_length = random.uniform(config.min_bar_length, 30)
			second_shortest_bar_length = shortest_bar_length / (1-config.delta_length)

		indexes_extrema_arr1 = random.sample(range(1, config.num_of_bars - 1), 2)
		indexes_extrema_arr2 = random.sample(range(1, config.num_of_bars - 1), 2)

		arr1_longest_length = longest_bar_length if config.longest_longer_side == 1 else second_longest_bar_length
		arr2_longest_length = longest_bar_length if config.longest_longer_side == 2 else second_longest_bar_length
		arr1_shortest_length = shortest_bar_length if config.shortest_longer_side == 2 else second_shortest_bar_length
		arr2_shortest_length = shortest_bar_length if config.shortest_longer_side == 1 else second_shortest_bar_length

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

	for sublist in arr1: sublist.append(random.randint(0, 6))
	for sublist in arr2: sublist.append(random.randint(0, 6))
	
	brightness_longest_darker = random.randint(config.delta_brightness, 6)
	brightness_longest_lighter = brightness_longest_darker - config.delta_brightness
	brightness_shortest_darker = random.randint(config.delta_brightness, 6)
	brightness_shortest_lighter = brightness_shortest_darker - config.delta_brightness

	if config.longest_darker_side == 1:
		arr1[indexes_longest[0]][2] = brightness_longest_darker
		arr2[indexes_longest[1]][2] = brightness_longest_lighter
	else:
		arr1[indexes_longest[0]][2] = brightness_longest_lighter
		arr2[indexes_longest[1]][2] = brightness_longest_darker

	if config.shortest_darker_side == 1:
		arr1[indexes_shortest[0]][2] = brightness_shortest_darker
		arr2[indexes_shortest[1]][2] = brightness_shortest_lighter
	else:
		arr1[indexes_shortest[0]][2] = brightness_shortest_lighter
		arr2[indexes_shortest[1]][2] = brightness_shortest_darker

	return [arr1, arr2, config.longest_darker_side, config.longest_longer_side, config.shortest_darker_side, config.shortest_longer_side, indexes_longest[:], indexes_shortest[:]]


if __name__=="__main__":
	main()


