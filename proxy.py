import pickle
import csv


with open('stimuli_range/stimuli.pickle', 'rb') as file:
    stimuli = pickle.load(file)

# [arr1, arr2, config.longerBar, config.laterBar, config.higherBar, config.darkerBar, redIndexPair[:]]
# [floor, length, color]

rows = []
for idx, s in enumerate(stimuli):
	arr1, arr2, longerBar, laterBar, higherBar, darkerBar, (redIndex1, redIndex2) = s
	floor1, length1, color1 = arr1[redIndex1]
	floor2, length2, color2 = arr2[redIndex2]
	indexDiffVerticalSide = redIndex2 + 10 - redIndex1
	indexDiffUnaligned = abs(redIndex2 - redIndex1)
	indexDiffHorizontalStacked = redIndex1 + 10 - redIndex2
	rows.append([idx, indexDiffVerticalSide, indexDiffUnaligned, indexDiffHorizontalStacked])

with open('Slope.csv', 'w', newline='') as csvfile:
    writer = csv.writer(csvfile)
    writer.writerow(['stimuli_number', 'indexDiffVerticalSide', 'indexDiffUnaligned', 'indexDiffHorizontalStacked'])
    writer.writerows(rows)