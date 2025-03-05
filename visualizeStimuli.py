import matplotlib.pyplot as plt
import numpy as np
import pickle
import os

def save_stimuli_images(stimuli, save_dir="stimuli"):
    """
    Saves each stimulus as two separate images:
    - One with `arr1` and `arr2` juxtaposed horizontally.
    - One with `arr1` and `arr2` juxtaposed vertically.
    
    Args:
        stimuli (list): A list of stimuli in the format [arr1, arr2, ans].
        save_dir (str): The root directory where images will be saved.
    """
    # Create folders for horizontal and vertical images
    horizontal_unlabeled_dir = os.path.join(save_dir, "horizontal", "unlabeled")
    vertical_unlabeled_dir = os.path.join(save_dir, "vertical", "unlabeled")
    horizontal_labeled_dir = os.path.join(save_dir, "horizontal", "labeled")
    vertical_labeled_dir = os.path.join(save_dir, "vertical", "labeled")
    os.makedirs(horizontal_unlabeled_dir, exist_ok=True)
    os.makedirs(vertical_unlabeled_dir, exist_ok=True)
    os.makedirs(horizontal_labeled_dir, exist_ok=True)
    os.makedirs(vertical_labeled_dir, exist_ok=True)

    yticks = [10*i for i in range(11)]

    for i, (arr1, arr2, ans) in enumerate(stimuli):
        x = [chr(ord('A') + i) for i in range(len(arr1))]
        # x = np.arange(len(arr1))  # X-axis positions

        # ---- HORIZONTAL IMAGE ----
        fig, axes = plt.subplots(1, 2, figsize=(6, 3))  # Two subplots side by side
        axes[0].bar(x, arr1, color='black', alpha=0.7)
        axes[1].bar(x, arr2, color='black', alpha=0.7)

        for ax in axes:
            ax.set_xticks([])
            ax.set_yticks([])
            ax.set_ylim(0, 100)  # Ensure y-axis scale is the same
            ax.spines['top'].set_visible(False)
            ax.spines['right'].set_visible(False)

        horizontal_path = os.path.join(horizontal_unlabeled_dir, f"stimulus_{i+1}.png")
        plt.savefig(horizontal_path, bbox_inches="tight", dpi=300)

        # ---- HORIZONTAL with LABELS ----
        for ax in axes:
            ax.set_xticks(x)
            ax.set_yticks(yticks)

        horizontal_label_path = os.path.join(horizontal_labeled_dir, f"stimulus_{i+1}.png")
        plt.savefig(horizontal_label_path, bbox_inches="tight", dpi=300)
        plt.close(fig)

        # ---- VERTICAL IMAGE ----
        fig, axes = plt.subplots(2, 1, figsize=(3, 6))  # Two subplots stacked
        axes[0].bar(x, arr1, color='black', alpha=0.7)
        axes[1].bar(x, arr2, color='black', alpha=0.7)

        for ax in axes:
            ax.set_xticks([])
            ax.set_yticks([])
            ax.set_ylim(0, 100)
            ax.spines['top'].set_visible(False)
            ax.spines['right'].set_visible(False)

        vertical_path = os.path.join(vertical_unlabeled_dir, f"stimulus_{i+1}.png")
        plt.savefig(vertical_path, bbox_inches="tight", dpi=300)

        # ---- VERTICAL with LABELS ----
        for ax in axes:
            ax.set_xticks(x)
            ax.set_yticks(yticks)

        vertical_label_path = os.path.join(vertical_labeled_dir, f"stimulus_{i+1}.png")
        plt.savefig(vertical_label_path, bbox_inches="tight", dpi=300)
        plt.close(fig)

        print(f"Saved {horizontal_path} and {vertical_path}")

# Load stimuli from pickle file
with open('stimuli.pickle', 'rb') as file:
    stimuli = pickle.load(file)

# Generate and save images
save_stimuli_images(stimuli)
