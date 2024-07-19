import { FiX } from "solid-icons/fi";
import { ImSpinner8 } from "solid-icons/im";
import { Component, createResource, For, Show, Switch, Match } from "solid-js";
import { Portal } from "solid-js/web";
import { cuttingTimeStr } from "../utils";

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
  name: string;
  onCloseEvent: () => void;
};

const getProgram = async (nest: string) => {
  if (nest === null) return {};

  const response = await fetch(`/api/nest/${nest}`);
  return response.json();
};

const NestInfo: Component<Props> = (props: Props) => {
  const name = () => props.name;
  const [nest] = createResource(name, getProgram);

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
    <Portal>
      <div
        class="absolute inset-0 z-40 h-full w-full bg-slate-500 opacity-75"
        onClick={props.onCloseEvent}
      ></div>
      <dialog
        class="fixed inset-0 z-50 overflow-auto rounded-lg border backdrop-blur-sm"
        open={true}
      >
        <Show when={nest.loading}>
          <main class="border-4 bg-gradient-to-tr from-sky-300 to-teal-400 p-16">
            <ImSpinner8 class="animate-spin" />
            Fetching nest data...
          </main>
        </Show>
        <Switch>
          <Match when={nest.error}>
            <main class="border-4 border-rose-500 bg-gradient-to-tr from-red-200 to-red-500 p-16">
              <span>Error: {nest.error()}</span>
            </main>
          </Match>
          <Match when={nest()}>
            <header class="flex items-center border-b-2 bg-gradient-to-tr from-amber-300 to-orange-400 p-2">
              <p class="mx-2 select-none rounded-full bg-cyan-400 px-2 font-mono text-xs">
                {nest().archivePacketId}
              </p>
              <p class="grow text-lg">
                <span class="select-all">{nest().program.programName}</span>
              </p>
              <FiX class="rounded hover:ring-2" onClick={props.onCloseEvent} />
            </header>
            <main class="grid grid-cols-1 divide-y p-4">
              <div class="p-2">
                <h1 class="text-lg font-semibold">Program</h1>
                <ul>
                  <li>Program: {nest().program.programName}</li>
                  <li>RepeatID: {nest().program.repeatId}</li>
                  <li>Runtime: {cuttingTimeStr(nest().program.cuttingTime)}</li>
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
                          <td class="px-2">
                            {part.nestedArea - part.trueArea}
                          </td>
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
                  <table class="rounded-xl border">
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
            <footer class="border-t-2 px-4 py-2">
              <button class="rounded bg-sky-500 px-2 py-1" onClick={exportInfo}>
                Export
              </button>
            </footer>
          </Match>
        </Switch>
      </dialog>
    </Portal>
  );
};

export { type Nest, NestInfo };
