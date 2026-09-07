const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

export async function connect(tab) {
    const socket = new WebSocket(tab.webSocketDebuggerUrl);
    await new Promise((resolve, reject) => {
        socket.onopen = resolve;
        socket.onerror = reject;
    });
    let id = 0;
    const pending = new Map();
    const errors = [];
    socket.onmessage = ({data}) => {
        const message = JSON.parse(data);
        if (message.id) {
            const callbacks = pending.get(message.id);
            pending.delete(message.id);
            if (message.error) callbacks.reject(new Error(message.error.message));
            else callbacks.resolve(message.result);
        } else if (message.method === 'Runtime.exceptionThrown') {
            errors.push(message.params.exceptionDetails.text);
        }
    };
    const call = (method, params = {}) => new Promise((resolve, reject) => {
        pending.set(++id, {resolve, reject});
        socket.send(JSON.stringify({id, method, params}));
    });
    const evaluate = async expression => {
        const result = await call('Runtime.evaluate', {expression,
            returnByValue: true, awaitPromise: true});
        if (result.exceptionDetails) throw new Error(result.exceptionDetails.text);
        return result.result.value;
    };
    return {call, evaluate, errors, close: () => socket.close()};
}

export async function waitFor(page, expression, label) {
    for (let i = 0; i < 200; i++) {
        if (await page.evaluate(expression)) return;
        await sleep(100);
    }
    throw new Error('Timed out: ' + label);
}

