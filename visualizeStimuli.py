import matplotlib.pyplot as plt
import numpy as np
import pickle
import os

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

    for i, (arr1, arr2, ans1, ans2, redIndexes) in enumerate(stimuli):
        x = [i+1 for i in range(len(arr1))]
        colors1 = ['red' if i == redIndexes[0] else 'black' for i in range(len(arr1))]
        colors2 = ['red' if i == redIndexes[1] else 'black' for i in range(len(arr2))]

        if layout == "horizontal":
            # ---- HORIZONTAL IMAGE ----
            fig, axes = plt.subplots(1, 2, figsize=(6, 3))  # Two subplots side by side
            axes[0].bar(x, arr1, color=colors1, alpha=0.7)
            axes[1].bar(x, arr2, color=colors2, alpha=0.7)

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



def main():
    # Load stimuli from pickle file
    with open('stimuli_red/stimuli_easy.pickle', 'rb') as file:
        stimuli = pickle.load(file)

    # Generate and save images
    save_stimuli_images(stimuli, save_dir = "stimuli_red/practice_easy", layout="horizontal", label=True)

if __name__=="__main__":
    main()
