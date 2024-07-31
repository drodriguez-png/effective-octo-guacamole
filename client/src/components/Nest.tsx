import { FiX, FiAlertTriangle } from "solid-icons/fi";
import { ImSpinner8 } from "solid-icons/im";
import { Component, createResource, For, Show, Switch, Match } from "solid-js";
import { Portal } from "solid-js/web";
import { cuttingTimeStr } from "../utils";

import { Nest } from "../nest";

type Props = {
  name: string;
  onCloseEvent: () => void;
};

const getProgram = async (nest: string) => {
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
          <main class="rounded-lg border-4 bg-gradient-to-tr from-sky-300 to-teal-400 p-4">
            <div class="flex items-center space-x-2 font-sans">
              <span>
                <ImSpinner8 class="animate-spin" />
              </span>
              <p>fetching nest data...</p>
            </div>
          </main>
        </Show>
        <Switch>
          <Match when={nest.error}>
            <main class="rounded-lg border-4 border-rose-500 bg-gradient-to-tr from-red-200 to-red-500 p-4">
              <div class="flex items-center space-x-2 font-sans">
                <span>
                  <FiAlertTriangle class="size-5 animate-pulse" />
                </span>
                <p>failed to retrieve nest data</p>
              </div>
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
                <table>
                  <tbody>
                    <tr class="m-4 hover:bg-gray-100">
                      <td class="px-2">
                        <strong>Program</strong>
                      </td>
                      <td class="px-2">
                        <span class="select-all decoration-sky-500">
                          {nest().program.programName}
                        </span>
                      </td>
                    </tr>
                    <tr class="m-4 border-t hover:bg-gray-100">
                      <td class="px-2">
                        <strong>RepeatID</strong>
                      </td>
                      <td class="px-2">{nest().program.repeatId}</td>
                    </tr>
                    <tr class="m-4 border-t hover:bg-gray-100">
                      <td class="px-2">
                        <strong>Runtime</strong>
                      </td>
                      <td class="px-2">
                        {cuttingTimeStr(nest().program.cuttingTime)}
                      </td>
                    </tr>
                  </tbody>
                </table>
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
