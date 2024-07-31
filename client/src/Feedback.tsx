import { FiAlertTriangle, FiRefreshCcw, FiX } from "solid-icons/fi";
import {
  createResource,
  onCleanup,
  createEffect,
  createSignal,
  Component,
  Suspense,
  Index,
  Match,
  Switch,
  For,
  Show,
} from "solid-js";
import { Portal } from "solid-js/web";
import { Nest } from "./nest";
import { ImSpinner8 } from "solid-icons/im";

const getFeedback = async () => {
  const response = await fetch(`/api/feedback`);
  return response.json();
};

export const Feedback: Component = () => {
  const [feedback, { refetch }] = createResource(getFeedback);
  const [feedbackToShow, setFeedbackToShow] = createSignal<Nest>();

  const showInfo = () => feedbackToShow() !== undefined;

  const exportInfo = () => {
    const blob = new Blob([JSON.stringify(feedbackToShow(), null, 2)], {
      type: "text/json",
    });
    const a = document.createElement("a");
    a.download = `${feedbackToShow()?.archivePacketId}.json`;
    a.href = window.URL.createObjectURL(blob);
    a.click();
    a.remove();
  };

  // const timer = setInterval(() => {
  //   refetch();
  // }, 60 * 1000);
  // onCleanup(() => clearInterval(timer));

  createEffect(() => {
    console.log(feedback());
  });

  createEffect(() => console.log(feedbackToShow()));

  return (
    <Suspense
      fallback={
        <p class="col-span-full row-span-full place-self-center">Fetching...</p>
      }
    >
      <div class="m-4 overflow-auto shadow-md sm:rounded-lg">
        <table class="w-full text-sm text-gray-500">
          <thead class="sticky top-0 z-10 bg-gradient-to-tr from-amber-300 to-orange-400 text-xs uppercase text-gray-700">
            <tr>
              <th scope="col" class="px-6 py-3">
                Archive Packet ID
              </th>
              <th scope="col" class="px-6 py-3">
                Type
              </th>
              <th scope="col" class="px-6 py-3">
                Program
              </th>
              <th scope="col" class="px-6 py-3">
                RepeatId
              </th>
              <th>
                <button
                  class="m-2 rounded p-2 hover:bg-slate-400"
                  onClick={refetch}
                >
                  <FiRefreshCcw />
                </button>
              </th>
            </tr>
          </thead>
          <tbody>
            <Index each={feedback()}>
              {(item) => (
                <tr
                  class="border-t py-4 hover:bg-gray-100"
                  onClick={() =>
                    typeof item().state !== "string"
                      ? setFeedbackToShow(item().state.created)
                      : null
                  }
                >
                  <th
                    scope="row"
                    class="whitespace-nowrap px-6 py-4 font-medium text-gray-900"
                  >
                    {item().archivePacketId}
                  </th>
                  <Switch
                    fallback={
                      <td class="px-6 py-4" colSpan={100}>
                        {item().state}
                      </td>
                    }
                  >
                    <Match when={typeof item().state !== "string"}>
                      <td class="px-6 py-4">{Object.keys(item().state)[0]}</td>
                      <td class="px-6 py-4">
                        {item().state.created.program.programName}
                      </td>
                      <td class="px-6 py-4" colSpan={100}>
                        {item().state.created.program.repeatId}
                      </td>
                    </Match>
                  </Switch>
                </tr>
              )}
            </Index>
          </tbody>
        </table>
        <Show when={showInfo()}>
          <Portal>
            <div
              class="absolute inset-0 z-40 h-full w-full bg-slate-500 opacity-75"
              onClick={() => setFeedbackToShow()}
            ></div>
            <dialog
              class="fixed inset-0 z-50 overflow-auto rounded-lg border backdrop-blur-sm"
              open={true}
            >
              <header class="flex items-center border-b-2 bg-gradient-to-tr from-amber-300 to-orange-400 p-2">
                <p class="mx-2 select-none rounded-full bg-cyan-400 px-2 font-mono text-xs">
                  {feedbackToShow()?.archivePacketId}
                </p>
                <p class="grow text-lg">
                  <span class="select-all">
                    {feedbackToShow()?.program.programName}
                  </span>
                </p>
                <FiX
                  class="rounded hover:ring-2"
                  onClick={() => setFeedbackToShow()}
                />
              </header>
              <main class="grid grid-cols-1 divide-y p-4">
                <div class="p-2">
                  <h1 class="text-lg font-semibold">Program</h1>
                  <ul>
                    <li>Program: {feedbackToShow()?.program.programName}</li>
                    <li>RepeatID: {feedbackToShow()?.program.repeatId}</li>
                    <li>Runtime: {feedbackToShow()?.program.cuttingTime}</li>
                  </ul>
                </div>
                <div class="p-2">
                  <h1 class="text-lg font-semibold">Sheet</h1>
                  <ul>
                    <li>Sheet Name: {feedbackToShow()?.sheet.sheetName}</li>
                    <li>
                      Material Master: {feedbackToShow()?.sheet.materialMaster}
                    </li>
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
                      <For each={feedbackToShow()?.parts}>
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
                    when={(feedbackToShow()?.remnants.length || 0) > 0}
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
                        <For each={feedbackToShow()?.remnants}>
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
                <button
                  class="rounded bg-sky-500 px-2 py-1"
                  onClick={exportInfo}
                >
                  Export
                </button>
              </footer>
            </dialog>
          </Portal>
        </Show>
      </div>
    </Suspense>
  );
};
