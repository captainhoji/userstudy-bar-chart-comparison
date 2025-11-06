import numpy as np
import random
import pickle
from itertools import product
from collections import Counter
from dataclasses import dataclass

@dataclass
class StimuliConfig:
	darkest_higher_side: int
	darkest_lower_side: int
	darkest_darker_side: int
	lightest_higher_side: int
	lightest_lower_side: int
	lightest_darker_side: int
	delta: float
	num_of_bars: int
	min_edge_gap: float
	min_bar_length: float = 30
	max_bar_length: float = 70
	delta_brightness: int = 1
	salience_brightness: int = 1

num_of_bars = 10
min_edge_gap = 5

stimuliDir = 'stimuli_bias'

def main():
	# delta_height, delta_index, delta
	deltas = [5, 10]
	all_combinations = list(product([1, 2], repeat=6))

	# real task
	stimuli = [
		generateTaskStimuli(StimuliConfig(
			darkest_higher_side=combo[0],
			darkest_lower_side=combo[1],
			darkest_darker_side=combo[2],
			lightest_higher_side=combo[3],
			lighest_lower_side=combo[4],
			lightest_darker_side=combo[5],
			delta=delta,
			num_of_bars=num_of_bars,
			min_edge_gap=min_edge_gap
		))
		for i in range(1)
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
			darkest_higher_side=combo[0],
			darkest_lower_side=combo[1],
			darkest_darker_side=combo[2],
			lightest_higher_side=combo[3],
			lighest_lower_side=combo[4],
			lightest_darker_side=combo[5],
			delta=.50,
			delta_brightness=0,
			num_of_bars=num_of_bars,
			min_bar_length=20,
			max_bar_length=80,
			salience_brightness=3,
			min_edge_gap=min_edge_gap
		))
		for combo in all_combinations
	]

	with open(stimuliDir + '/validation_stimuli.pickle', 'wb') as file:
	    pickle.dump(validation_stimuli, file)

	# hard practice
	stimuli_practice = [
		generateTaskStimuli(StimuliConfig(
			darkest_higher_side=combo[0],
			darkest_lower_side=combo[1],
			darkest_darker_side=combo[2],
			lightest_higher_side=combo[3],
			lighest_lower_side=combo[4],
			lightest_darker_side=combo[5],
			delta=delta,
			num_of_bars=num_of_bars,
			min_edge_gap=min_edge_gap
		))
		for i in range(1)
		for combo in all_combinations
		for delta in deltas
	]

	with open(stimuliDir + '/practice.pickle', 'wb') as file:
	    pickle.dump(stimuli_practice, file)

	# easy practice
	stimuli_easy = [
		generateTaskStimuli(StimuliConfig(
			darkest_higher_side=combo[0],
			darkest_lower_side=combo[1],
			darkest_darker_side=combo[2],
			lightest_higher_side=combo[3],
			lighest_lower_side=combo[4],
			lightest_darker_side=combo[5],
			delta=.50,
			delta_brightness=1,
			num_of_bars=num_of_bars,
			min_bar_length=20,
			max_bar_length=80,
			salience_brightness=2,
			min_edge_gap=min_edge_gap
		))
		for i in range(1)
		for combo in all_combinations
	]

	with open(stimuliDir + '/stimuli_easy.pickle', 'wb') as file:
	    pickle.dump(stimuli_easy, file)

def createBarChartArray(darkest_bar_length, darkest_bar_index, lightest_bar_length, lightest_bar_index, config: StimuliConfig, volume_chart1 = 0):
	if volume_chart1 == 0:
		bar_lengths = random.sample(range(config.min_bar_length, config.max_bar_length+1), config.num_of_bars-2)
	else:
		# while True:
		bar_lengths = []
		remaining_volume = volume_chart1 - darkest_bar_length - lightest_bar_length
		for i in range(config.num_of_bars - 3):
			# Calculate the valid range for this bar length
			min_possible = max(config.min_bar_length, remaining_volume - (config.num_of_bars - 1 - (i + 1)) * config.max_bar_length)
			max_possible = min(config.max_bar_length, remaining_volume - (config.num_of_bars - 1 - (i + 1)) * config.min_bar_length)

			# Sample within the valid range
			length = np.random.uniform(min_possible, max_possible)
			bar_lengths.append(length)
			remaining_volume -= length
			# if config.min_bar_length <= remaining_volume and remaining_volume <= config.max_bar_length:
			# 	break

		# Assign the last bar to exactly match the remaining volume
		bar_lengths.append(remaining_volume)

	random.shuffle(bar_lengths)

	# make sure the insertions are made from the smallest to largest index
	if darkest_bar_index < lightest_bar_index:
		bar_lengths.insert(darkest_bar_index, darkest_bar_length)
		bar_lengths.insert(lightest_bar_index, lightest_bar_length)
	else:
		bar_lengths.insert(lightest_bar_index, lightest_bar_length)
		bar_lengths.insert(darkest_bar_index, darkest_bar_length)

	volume = sum(bar_lengths) + darkest_bar_length + lightest_bar_length
	bars = [[floor := np.random.uniform(config.min_edge_gap, 100-config.min_edge_gap-length), floor + length] for length in bar_lengths]
	return bars, volume

def generateTaskStimuli(config: StimuliConfig):
	while True:
		darkest_higher_bar_ceiling = random.uniform(config.min_edge_gap, 100-config.min_edge_gap)
		darkest_not_higher_bar_ceiling = 

		darkest_higher_bar_length = random.uniform(config.min_bar_length, config.max_bar_length)
		darkest_lower_bar_length = darkest_higher_bar_length * (1 - config.delta)
		lightest_higher_bar_length = random.uniform(config.min_bar_length, config.max_bar_length)
		lightest_lower_bar_length = lightest_higher_bar_length * (1 - config.delta)

		indexes_extrema_arr1 = random.sample(range(1, config.num_of_bars - 1), 2)
		indexes_extrema_arr2 = random.sample(range(1, config.num_of_bars - 1), 2)

		arr1_darkest_length = darkest_higher_bar_length if config.darkest_higher_side == 1 else darkest_lower_bar_length
		arr1_lightest_length = lightest_higher_bar_length if config.lightest_higher_side == 1 else lightest_lower_bar_length
		arr2_darkest_length = darkest_higher_bar_length if config.darkest_higher_side == 2 else darkest_lower_bar_length
		arr2_lightest_length = lightest_higher_bar_length if config.lightest_higher_side == 2 else lightest_lower_bar_length

		arr1, volume_arr1 = createBarChartArray(arr1_darkest_length, indexes_extrema_arr1[0], arr1_lightest_length, indexes_extrema_arr1[1], config)
		arr2, _ = createBarChartArray(arr2_darkest_length, indexes_extrema_arr2[0], arr2_lightest_length, indexes_extrema_arr2[1], config, volume_chart1 = volume_arr1)

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

	# for output purposes so that front end does not need to calcualte which bars are the darkest/lightest
	indexes_darkest = [indexes_extrema_arr1[0], indexes_extrema_arr2[0]] # [darkest bar of arr1, darkest bar of arr2]
	indexes_lightest = [indexes_extrema_arr1[1], indexes_extrema_arr2[1]] # [lightest bar of arr1, lightest bar of arr2]
	brightness_default = 3

	for sublist in arr1: sublist.append(brightness_default)
	for sublist in arr2: sublist.append(brightness_default)
	
	brightness_darkest = random.randint(brightness_default + config.salience_brightness + config.delta_brightness, 6)
	brightness_second_darkest = brightness_darkest - config.delta_brightness
	arr1[indexes_extrema_arr1[0]][2] = brightness_darkest if config.darkest_darker_side == 1 else brightness_second_darkest
	arr2[indexes_extrema_arr2[0]][2] = brightness_second_darkest if config.darkest_darker_side == 1 else brightness_darkest

	brightness_lightest = random.randint(0, brightness_default - config.salience_brightness - config.delta_brightness)
	brightness_second_lightest = brightness_lightest + config.delta_brightness
	arr1[indexes_extrema_arr1[1]][2] = brightness_lightest if config.lightest_darker_side == 2 else brightness_second_lightest
	arr2[indexes_extrema_arr2[1]][2] = brightness_second_lightest if config.lightest_darker_side == 2 else brightness_lightest

	return [arr1, arr2, config.darkest_higher_side, config.darkest_darker_side, config.lightest_higher_side, config.lightest_darker_side, indexes_darkest[:], indexes_lightest[:]]


if __name__=="__main__":
	main()


