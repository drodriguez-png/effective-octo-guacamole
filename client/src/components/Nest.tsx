import { FiX } from "solid-icons/fi";
import { Component, createEffect, createSignal, For, Show } from "solid-js";

type Nest = {
  archivePacketId: number;
  program: Program;
  parts: Part[];
  sheet: Sheet;
  remnants: Remnant[];
};

type Part = {
  partName: string;
  partQty: number;
  job: string;
  shipment: number;
  nestedArea: number;
  trueArea: number;
};

type Program = {
  programName: string;
  repeatId: number;
  machineName: string;
  cuttingTime: number;
};

type Sheet = {
  materialMaster: string;
  sheetName: string;
};

type Remnant = {
  remnantName: string;
  length: number;
  width: number;
  area: number;
};

type Props = {
  nest: Nest;
};

const NestInfo: Component<Props> = (props: Props) => {
  const nest = () => props.nest;
  const [open, setOpen] = createSignal(true);

  createEffect(() => {
    console.log(nest());
    setOpen(true);
  });

  const exportInfo = () => {
    const blob = new Blob([JSON.stringify(nest(), null, 2)], {
      type: "text/json",
    });
    const a = document.createElement("a");
    a.download = `${nest().program.programName}.json`;
    a.href = window.URL.createObjectURL(blob);
    a.click();
    a.remove();
  };

  return (
    <dialog
      class="z-50 fixed inset-0 border rounded-lg backdrop-blur-sm overflow-auto"
      open={open()}
    >
      <header class="flex items-center p-2 border-b-2 bg-gradient-to-tr from-amber-300 to-orange-400">
        <p class="grow">
          <span class="select-all">{nest().program.programName}</span>
        </p>
        <FiX class="rounded hover:ring-2" onClick={() => setOpen(false)} />
      </header>
      <main class="p-4 grid grid-cols-1 divide-y">
        <div class="p-2">
          <h1 class="text-lg font-semibold">Program</h1>
          <ul>
            <li>Program: {nest().program.programName}</li>
            <li>Runtime: {nest().program.cuttingTime}</li>
          </ul>
        </div>
        <div class="p-2">
          <h1 class="text-lg font-semibold">Sheet</h1>
          <ul>
            <li>Sheet Name: {nest().sheet.sheetName}</li>
            <li>Material Master: {nest().sheet.materialMaster}</li>
          </ul>
        </div>
        <div class="p-2">
          <h1 class="text-lg font-semibold">Parts</h1>
          <table class="rounded-lg bg-slate-100">
            <thead>
              <tr class="border-b-2">
                <th class="px-2">Name</th>
                <th class="px-2">Qty</th>
                <th class="px-2">Job</th>
                <th class="px-2">Shipment</th>
                <th class="px-2">Part Area</th>
                <th class="px-2">Skeleton Area</th>
              </tr>
            </thead>
            <tbody>
              <For each={nest().parts}>
                {(part) => (
                  <tr class="border-t hover:bg-gray-200">
                    <td class="px-2">{part.partName}</td>
                    <td class="px-2">{part.partQty}</td>
                    <td class="px-2">{part.job}</td>
                    <td class="px-2">{part.shipment}</td>
                    <td class="px-2">{part.trueArea}</td>
                    <td class="px-2">{part.nestedArea - part.trueArea}</td>
                  </tr>
                )}
              </For>
            </tbody>
          </table>
        </div>
        <div class="p-2">
          <h1 class="text-lg font-semibold">Remnants</h1>
          <Show
            when={nest().remnants.length > 0}
            fallback={<p class="text-center">no remnants</p>}
          >
            <table class="border rounded-xl">
              <thead class="border">
                <tr>
                  <th class="border">Name</th>
                  <th>Width</th>
                  <th>Length</th>
                  <th>Area</th>
                </tr>
              </thead>
              <tbody>
                <For each={nest().remnants}>
                  {(rem) => (
                    <tr class="border-t hover:bg-gray-100">
                      <td>{rem.remnantName}</td>
                      <td>{rem.width}</td>
                      <td>{rem.length}</td>
                      <td>{rem.area}</td>
                    </tr>
                  )}
                </For>
              </tbody>
            </table>
          </Show>
        </div>
      </main>
      <footer class="px-4 py-2 border-t-2">
        <button class="rounded px-2 py-1 bg-sky-500" onClick={exportInfo}>
          Export
        </button>
      </footer>
    </dialog>
  );
};

export { type Nest, NestInfo };
