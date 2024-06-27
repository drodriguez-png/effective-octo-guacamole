import { Form, Button, FloatingLabel } from "solid-bootstrap";
import { Component, createEffect, createSignal, mergeProps, onMount } from "solid-js";

interface Program {
  name: String;
  batches: string[];
  remnant: Remnant | null;
}

interface Remnant {
  width: number;
  length: number;
}

const BatchAssign: Component = () => {
  const [program, setProgram] = createSignal<Program | null>(null);
  const [batch, setBatch] = createSignal<string>("");

  const [selectedMachine, setSelectedMachine] = createSignal<string>("");
  const [machines, setMachines] = createSignal<string[]>([]);
  const [programs, setPrograms] = createSignal<string[]>([]);

  onMount(async () => {
    const res = await (await fetch(`/api/machines`)).json();

    console.log(res);
    setMachines(res.machines);
  });

  createEffect(() => console.log(program()));

  // get list of programs when machine is selected
  createEffect(async () => {
    const url =
      `/api/programs?` + new URLSearchParams({ machine: selectedMachine() });
    const res = await (await fetch(url)).json();

    console.log(res);
    setPrograms(res.programs);
  });

  // get program data when program changes
  const selectProgram = async (pname: string) => {
    const url = `/api/program?` + new URLSearchParams({ program: pname });
    const res = await (await fetch(url)).json();

    setProgram(res);
  };

  const setWidth = (width: number) => setProgram(mergeProps(program(), { "width": width }));
  const setLength = (length: number) => setProgram(mergeProps(program(), { "length": length }));

  const handleSubmit = async (e: Event) => {
    e.preventDefault();
    alert(`Selected Program: ${program()}, Selected Batch: ${batch()}`);

    // POST to backend
    const res = await fetch(`/api/program`, {
      method: "POST",
      body: JSON.stringify({
        program: program(),
        batch: batch(),
      }),
      headers: {
        "Content-type": "application/json; charset=UTF-8",
      },
    });

    console.log(res);
  };

  return (
    <>
      <select
        id="machine"
        class="border border-gray-300 rounded py-2 px-3 text-gray-700 focus:outline-none focus:ring focus:border-blue-500"
        value={selectedMachine()}
        onInput={(e) =>
          setSelectedMachine((e.target as HTMLSelectElement).value)
        }
      >
        <option value="" disabled>
          Select a machine
        </option>
        {machines().map((machine) => (
          <option value={machine}>{machine}</option>
        ))}
      </select>

      <Form onSubmit={handleSubmit}>
        <FloatingLabel label="Program">
          <Form.Select
            disabled={!selectedMachine()}
            onInput={(e) =>
              selectProgram((e.target as HTMLSelectElement).value)
            }
          >
            {programs().map((program) => (
              <option value={program}>{program}</option>
            ))}
          </Form.Select>
        </FloatingLabel>
        <FloatingLabel label="Batch">
          <Form.Select
            disabled={(program()?.batches.length || 0) <= 1}
            onInput={(e) => setBatch((e.target as HTMLSelectElement).value)}
          >
            {program()?.batches.map((batch) => (
              <option value={batch}>{batch}</option>
            ))}
          </Form.Select>
        </FloatingLabel>
        <FloatingLabel label="Remnant Width">
          <Form.Control
            type="number"
            disabled={!program()?.remnant}
            value={program()?.remnant?.width}
            onInput={(e) =>
              setWidth(Number.parseFloat((e.target as HTMLInputElement).value))
            }
          />
        </FloatingLabel>
        <FloatingLabel label="Remnant Length">
          <Form.Control
            type="number"
            disabled={!program()?.remnant}
            value={program()?.remnant?.length}
            onInput={(e) =>
              setLength(Number.parseFloat((e.target as HTMLInputElement).value))
            }
          />
        </FloatingLabel>

        <Button variant="primary" type="submit">
          Submit
        </Button>
      </Form>
    </>
  );
};

export default BatchAssign;
