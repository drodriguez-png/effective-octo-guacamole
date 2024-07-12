import {
  Component,
  Match,
  Show,
  Switch,
  createResource,
  createSignal,
  onMount,
} from "solid-js";
import DropList from "./components/DropList";

const getPrograms = async (machine: string) => {
  if (!machine) return;

  localStorage.setItem("machine", machine);

  const response = await fetch(`/api/${machine}`);
  return response.json();
};

const BatchAssign: Component = () => {
  const [machines, setMachines] = createSignal([]);
  const [machine, setMachine] = createSignal(
    localStorage.getItem("machine") || ""
  );
  const [programs] = createResource(machine, getPrograms);

  const [program, setProgram] = createSignal("");

  onMount(async () => {
    const response = await fetch(`/api/machines`);
    setMachines(await response.json());
  });

  return (
    <div class="flex w-3/5 min-w-96 rounded-2xl overflow-hidden">
      <aside class="bg-gradient-to-tr from-amber-300 to-orange-400 flex flex-col justify-between p-2 min-w-48 min-h-48">
        <h1 class="text-2xl grow">Batch Assign</h1>
        <DropList
          class="self-end"
          name="machine"
          items={machines()}
          setValue={setMachine}
          value={machine()}
        />
      </aside>
      <section class="bg-amber-300 grow grid grid-cols-4 gap-2 p-2">
        <Show when={programs.loading}>
          <p class="col-span-full row-span-full place-self-center">
            Fetching...
          </p>
        </Show>
        <Switch>
          <Match when={!machine()}>
            <p class="col-span-full place-self-center">No machine selected</p>
          </Match>
          <Match when={programs.error}>
            <p class="col-span-full place-self-center">
              Error fetching programs
            </p>
            <p class="cols-span-full place-self-center font-mono">
              {programs.error}
            </p>
          </Match>
          <Match when={programs()}>
            <DropList
              class="col-start-2 col-span-2 place-self-center"
              name="program"
              items={programs()}
              setValue={setProgram}
            />
            <p class="col-start-1">Batch</p>
            <p class="col-start-1">Remnants</p>
            <p class="col-start-1">parts</p>
          </Match>
        </Switch>
      </section>
    </div>
  );
};

export default BatchAssign;
