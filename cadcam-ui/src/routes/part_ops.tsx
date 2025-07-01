import { Title } from "@solidjs/meta";
import { createSignal, createMemo } from "solid-js";
import "../styles/PartOps.css";

export default function PartOps() {
  const [job, setJob] = createSignal("");
  const [partName, setPartName] = createSignal("");
  const [operation1, setOperation1] = createSignal("");
  const [operation2, setOperation2] = createSignal("");
  const [operation3, setOperation3] = createSignal("");

  const operationOptions = [
    "Drill",
    "Drill/End Mill", 
    "Punch",
    "Rojar",
    "Press",
    "Drill(NX)"
  ];

  const isDrillOperation = (operation: string) => {
    return operation.toLowerCase().includes('drill');
  };

  // TODO: Add logic to limit operation options based on business rules
  // TODO: pull parts list from database
  // TODO: change part operations
  // TODO: add new as popup

  const handleSubmit = async (e: Event) => {
    e.preventDefault();
    
    try {
      const partNames = partName().split(',').map(name => name.trim()).filter(Boolean);
      const results = [];
      
      for (const singlePartName of partNames) {
        const response = await fetch('/api/part_ops', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            partName: `${job()}_${singlePartName}`,
            operation1: operation1(),
            operation2: operation2(),
            operation3: operation3()
          })
        });

        const result = await response.json();
        results.push({ partName: singlePartName, result });
      }
      
      const successful = results.filter(r => r.result.success);
      const failed = results.filter(r => !r.result.success);
      
      if (failed.length === 0) {
        alert(`All ${successful.length} part operations submitted successfully!`);
        // Reset form
        // setJob("");
        setPartName("");
        setOperation1("");
        setOperation2("");
        setOperation3("");
      } else {
        const failedParts = failed.map(f => f.partName).join(', ');
        alert(`${successful.length} parts submitted successfully. Failed parts: ${failedParts}`);
      }
    } catch (error) {
      console.error('Error submitting part operations:', error);
      alert('Error submitting part operations. Please try again.');
    }
  };

  return (
    <main>
      <Title>Part Operations</Title>
      <h1>Part Operations</h1>
      
      <form onSubmit={handleSubmit} class="part-ops-form">
        <div class="form-group">
          <label for="job" class="form-label">
            Job:
          </label>
          <input
            id="job"
            type="text"
            value={job()}
            onInput={(e) => setJob(e.currentTarget.value)}
            class="form-input"
            required
          />
        </div>

        <div class="form-group">
          <label for="partName" class="form-label">
            Part Name (comma-separated for multiple):
          </label>
          <input
            id="partName"
            type="text"
            value={partName()}
            onInput={(e) => setPartName(e.currentTarget.value)}
            class="form-input"
            required
            placeholder="e.g. PART1, PART2, PART3"
          />
        </div>

        <div class="form-group">
          <label for="operation1" class="form-label">
            Operation 1:
          </label>
          <select
            id="operation1"
            value={operation1()}
            onChange={(e) => setOperation1(e.currentTarget.value)}
            class="form-select"
          >
            <option value="">Select an operation</option>
            {operationOptions.map(option => (
              <option value={option}>{option}</option>
            ))}
          </select>
        </div>

        <div class="form-group">
          <label for="operation2" class="form-label">
            Operation 2:
          </label>
          <select
            id="operation2"
            value={operation2()}
            onChange={(e) => setOperation2(e.currentTarget.value)}
            class="form-select"
          >
            <option value="">Select an operation</option>
            {operationOptions.map(option => (
              <option value={option}>{option}</option>
            ))}
          </select>
        </div>

        <div class="form-group">
          <label for="operation3" class="form-label">
            Operation 3:
          </label>
          <select
            id="operation3"
            value={operation3()}
            onChange={(e) => setOperation3(e.currentTarget.value)}
            class="form-select"
          >
            <option value="">Select an operation</option>
            {operationOptions.map(option => (
              <option value={option}>{option}</option>
            ))}
          </select>
        </div>

        <button type="submit" class="submit-button">
          Submit
        </button>
      </form>
    </main>
  );
}
