import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
import numpy as np
import pickle
import os
import csv

def save_stimuli_images(stimuli, save_dir, layout, label):
    """
    Saves each stimulus as two separate images:
    - One with `arr1` and `arr2` juxtaposed horizontally.
    - One with `arr1` and `arr2` juxtaposed vertically.
    
    Args:
        stimuli (list): A list of stimuli in the format [arr1, arr2, ans].
        save_dir (str): The root directory where images will be saved.
    """
    os.makedirs(save_dir, exist_ok=True)

    yticks = [10*i for i in range(11)]
    cmap = plt.cm.Reds
    norm = mcolors.Normalize(vmin=1, vmax=7)


    for i, (arr1, arr2, ans1, ans2, ans3, ans4, redIndexes) in enumerate(stimuli):
        x = [i+1 for i in range(len(arr1))]

        if layout == "horizontal":
            # ---- HORIZONTAL IMAGE ----
            fig, axes = plt.subplots(1, 2, figsize=(6, 3))  # Two subplots side by side
            axes[0].bar(x, [e[1] for e in arr1], bottom=[e[0] for e in arr1], color=[cmap(norm(e[2])) for e in arr1], alpha=1)
            axes[1].bar(x, [e[1] for e in arr2], bottom=[e[0] for e in arr2], color=[cmap(norm(e[2])) for e in arr2], alpha=1)

            if not label:
                for ax in axes:
                    ax.set_xticks([])
                    ax.set_yticks([])
                    ax.set_ylim(0, 100)  # Ensure y-axis scale is the same
                    ax.spines['top'].set_visible(False)
                    ax.spines['right'].set_visible(False)

            else:
                for ax in axes:
                    ax.set_xticks(x)
                    ax.set_yticks(yticks)
                    ax.grid(True, axis='y', linestyle='--', alpha=0.5)

        else:
            # ---- VERTICAL IMAGE ----
            fig, axes = plt.subplots(2, 1, figsize=(3, 6))  # Two subplots stacked
            axes[0].bar(x, arr1, color=colors1, alpha=0.7)
            axes[1].bar(x, arr2, color=colors2, alpha=0.7)

            if not label:
                for ax in axes:
                    ax.set_xticks([])
                    ax.set_yticks([])
                    ax.set_ylim(0, 100)
                    ax.spines['top'].set_visible(False)
                    ax.spines['right'].set_visible(False)

            else:
                for ax in axes:
                    ax.set_xticks(x)
                    ax.set_yticks(yticks)
                    ax.grid(True, axis='y', linestyle='--', alpha=0.5)

        save_filename = os.path.join(save_dir, f"stimulus_{i+1}.png")
        plt.savefig(save_filename, bbox_inches="tight", dpi=300)
        plt.close(fig)

        print(f"Saved {save_filename}")

def checkAnswerCongruence(stimuli):
    data = [["stimuli_number", "answer_match"]]
    for i, s in enumerate(stimuli):
        if s[2] == s[3]:
            data.append([i, "yes"])
            data.append([-i, "yes"])
        else:
            data.append([i, "no"])
            data.append([-i, "no"])
    return data

def main():
    # Load stimuli from pickle file
    with open('stimuli_range/stimuli.pickle', 'rb') as file:
        stimuli = pickle.load(file)

    for s in stimuli:
        print(s[2:6])
    # Generate and save images
    # save_stimuli_images(stimuli, save_dir = "stimuli_range", layout="horizontal", label=False)
    # save_stimuli_images(stimuli, save_dir = "stimuli_range", layout="vertical", label=True)

    # data = checkAnswerCongruence(stimuli)
    # with open("stimuli_range_answers.csv", "w", newline="") as file:
    #     writer = csv.writer(file)
    #     writer.writerows(data)

if __name__=="__main__":
    main()
