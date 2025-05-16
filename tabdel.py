import tkinter as tk
import time
import pyautogui
import threading

# Global flag to control the loop
running = False

def perform_tab_delete():
    global running
    
    if running:
        # Already running, don't start another thread
        return
    
    # Set running flag to True
    running = True
    # Update button states
    do_it_button.config(state=tk.DISABLED)
    stop_button.config(state=tk.NORMAL)
    
    # Start the automation in a separate thread to keep GUI responsive
    automation_thread = threading.Thread(target=run_automation)
    automation_thread.daemon = True
    automation_thread.start()

def run_automation():
    global running
    
    # Give the user a moment to switch to the target application
    status_label.config(text="Starting in 3 seconds...")
    root.update()
    time.sleep(3)
    
    cycle_count = 0
    
    # Continue running until the stop button is pressed
    while running:
        cycle_count += 1
        status_label.config(text=f"Starting cycle #{cycle_count}")
        root.update()
        
        # Perform Tab + Delete 18 times
        for i in range(18):
            # Check if stopped
            if not running:
                break
                
            # Press Tab key
            pyautogui.press('tab')
            # Brief pause
            time.sleep(0.05)
            # Press Delete key
            pyautogui.press('delete')
            # Brief pause between iterations
            time.sleep(0.05)
            
            # Update counter in the GUI
            status_label.config(text=f"Cycle #{cycle_count}: Completed {i+1}/18 Tab+Delete sequences")
            root.update()
        
        if running:
            status_label.config(text=f"Completed cycle #{cycle_count}. Starting next cycle...")
            time.sleep(2)  # Short pause between cycles
    
    # Update status and button states when stopped
    status_label.config(text="Automation stopped")
    do_it_button.config(state=tk.NORMAL)
    stop_button.config(state=tk.DISABLED)

def stop_automation():
    global running
    running = False
    status_label.config(text="Stopping automation...")

# Create the main window
root = tk.Tk()
root.title("Tab+Delete Automation")
root.geometry("360x200")

# Create a frame for better layout
frame = tk.Frame(root, padx=20, pady=20)
frame.pack(expand=True, fill="both")

# Create button frame for layout
button_frame = tk.Frame(frame)
button_frame.pack(pady=10)

# Create the "Do It" button
do_it_button = tk.Button(
    button_frame, 
    text="START", 
    command=perform_tab_delete,
    font=("Arial", 14, "bold"),
    bg="#4CAF50",
    fg="white",
    height=2,
    width=10
)
do_it_button.pack(side=tk.LEFT, padx=5)

# Create the Stop button
stop_button = tk.Button(
    button_frame,
    text="STOP",
    command=stop_automation,
    font=("Arial", 14, "bold"),
    bg="#F44336",
    fg="white",
    height=2,
    width=10,
    state=tk.DISABLED  # Initially disabled
)
stop_button.pack(side=tk.LEFT, padx=5)

# Status label to show progress
status_label = tk.Label(frame, text="Ready to perform Tab+Delete", font=("Arial", 10))
status_label.pack(pady=10)

# Start the GUI event loop
root.mainloop()