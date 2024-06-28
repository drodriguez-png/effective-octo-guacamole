
import { Component, createContext  } from "solid-js";
import DropList from "./components/DropList";

const MachineContext = createContext();

const BatchAssignNew: Component = () => {

  return (
    <div class="flex w-3/5 min-w-96 rounded-2xl overflow-hidden">
      <aside class="bg-gradient-to-tr from-amber-300 to-orange-400 flex flex-col justify-between p-2 min-w-48 min-h-48">
        <h1 class="text-2xl grow">Batch Assign</h1>
        <DropList class="self-end" name="machine" items={["gemini", "titan", "kinetic"]} />
      </aside>
      <section class="bg-amber-300 grow grid grid-cols-4 gap-2 p-2">
        <p class="col-start-2 col-span-2 place-self-center">Program</p>
        <p class="col-start-1">Batch</p>
        <p class="row-start-3">Remnants</p>
      </section>
    </div>
  );
};

export default BatchAssignNew;
