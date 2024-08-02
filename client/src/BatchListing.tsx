import {
  Component,
  For,
  Show,
  Suspense,
  createEffect,
  createMemo,
  createResource,
  createSignal,
  onCleanup,
} from "solid-js";
import { FiRefreshCcw, FiX } from "solid-icons/fi";
import { Portal } from "solid-js/web";
import { Batch } from "./api/batch";

type QtyBatch = {
  qty: number;
  batch: Batch;
};

const getBatches = async () => {
  const response = await fetch(`/api/batches`);
  return response.json();
};

export const BatchListing: Component = () => {
  const [batches, { refetch }] = createResource(getBatches);
  const [batchToShow, setBatchToShow] = createSignal<Batch>();
  const [showInfo, setShowInfo] = createSignal(false);

  const [grouped, setGrouped] = createSignal(false);
  const ungroupedBatches = createMemo(() =>
    batches()?.map((batch: Batch) => [batch, 1]),
  );
  const groupedBatches = createMemo<[Batch, number][]>(() =>
    batches()
      ? Object.values(
          batches()?.reduce((res: any, val: Batch) => {
            if (!res[val.sheetName]) res[val.sheetName] = [val, 0];

            res[val.sheetName][1]++;

            return res;
          }, {}),
        )
      : [],
  );

  // const machinesListTimer = setInterval(() => {
  //   refetch();
  // }, 60 * 1000);
  // onCleanup(() => clearInterval(machinesListTimer));

  createEffect(() => {
    console.log(batches());
  });

  const showBatch = (batch: Batch) => {
    setBatchToShow(batch);
    setShowInfo(true);
  };

  return (
    <>
      <Suspense
        fallback={
          <p class="col-span-full row-span-full place-self-center">
            Fetching...
          </p>
        }
      >
        <label>
          <input
            type="checkbox"
            checked={grouped()}
            onChange={() => setGrouped((prev) => !prev)}
          />
          Group batches
        </label>
        <div class="m-4 overflow-y-hidden rounded-lg shadow-md hover:overflow-y-auto">
          <table class="w-full text-sm text-gray-500">
            <thead class="sticky top-0 z-10 bg-gradient-to-tr from-amber-300 to-orange-400 text-xs uppercase text-gray-700">
              <tr>
                <th scope="col" class="px-6 py-3">
                  Batch
                </th>
                <th scope="col" class="px-6 py-3">
                  Sheet Name
                </th>
                <th scope="col" class="px-6 py-3">
                  Material Master
                </th>
                <Show when={grouped}>
                  <th scope="col" class="px-6 py-3">
                    Qty
                  </th>
                </Show>
                <th scope="col" class="px-6 py-3">
                  Type
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
              <For each={grouped() ? groupedBatches() : ungroupedBatches()}>
                {([item, qty]) => (
                  <tr
                    class="border-t py-4 hover:bg-gray-100"
                    onClick={() => showBatch(item)}
                  >
                    <th
                      scope="row"
                      class="whitespace-nowrap px-6 py-4 font-medium text-gray-900"
                    >
                      {item.id}
                    </th>
                    <td class="px-6 py-4">{item.sheetName}</td>
                    <td class="px-6 py-4">{item.mm}</td>
                    <Show when={grouped}>
                      <td class="px-6 py-3">{qty}</td>
                    </Show>
                    <td class="px-6 py-4" colspan={2}>
                      {item.type}
                    </td>
                  </tr>
                )}
              </For>
            </tbody>
          </table>

          <Show when={showInfo()}>
            <Portal>
              <div
                class="absolute inset-0 z-40 h-full w-full bg-slate-500 opacity-75"
                onClick={() => setShowInfo(false)}
              ></div>
              <dialog
                class="fixed inset-0 z-50 overflow-auto rounded-lg border backdrop-blur-sm"
                open={showInfo()}
              >
                <header class="border-b-2 bg-gradient-to-tr from-amber-300 to-orange-400 p-2">
                  <p>
                    <span class="select-all">{batchToShow()?.id}</span>
                  </p>
                  <FiX
                    class="absolute right-2 top-2 rounded hover:ring-2"
                    onClick={() => setShowInfo(false)}
                  />
                </header>
                <main class="p-4">
                  <div class="m-4 overflow-auto shadow-md sm:rounded-lg">
                    <table>
                      <tbody>
                        <tr class="m-4 hover:bg-gray-100">
                          <td class="px-2">
                            <strong>Material Master</strong>
                          </td>
                          <td class="px-2">
                            <span class="select-all decoration-sky-500">
                              {batchToShow()?.mm}
                            </span>
                          </td>
                        </tr>
                        <tr class="m-4 border-t hover:bg-gray-100">
                          <td class="px-2">
                            <strong>Batch Type</strong>
                          </td>
                          <td class="px-2">{batchToShow()?.type}</td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </main>
              </dialog>
            </Portal>
          </Show>
        </div>
      </Suspense>
    </>
  );
};
