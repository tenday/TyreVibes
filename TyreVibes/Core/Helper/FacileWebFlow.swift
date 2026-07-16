import Foundation

enum FacileWebFlowError: LocalizedError {
    case invalidJavaScriptValue

    var errorDescription: String? {
        "Impossibile preparare la ricerca veicolo"
    }
}

enum FacileWebFlow {
    static let lookupURL = URL(string: "https://www.facile.it/assicurazioni-auto/preventivo.html")!
    static let messageHandlerName = "facileVehicleNative"

    static func interceptionScript(plate: String) throws -> String {
        let plateValue = try javaScriptString(plate)
        return #"""
        (() => {
          if (window.__tyreVibesFacileInstalled) return;
          window.__tyreVibesFacileInstalled = true;

          const send = value => {
            try {
              window.__tyreVibesResponseSent = true;
              window.webkit.messageHandlers.facileVehicleNative.postMessage(value);
            } catch (_) {}
          };

          const originalFetch = window.fetch.bind(window);
          window.fetch = async (...args) => {
            const response = await originalFetch(...args);
            const requestURL = args[0] instanceof Request ? args[0].url : String(args[0]);

            if (requestURL.includes('validate-plate')) {
              try {
                const payload = await response.clone().json();
                const vehicle = payload && payload.right && payload.right.vehicle;
                const target = vehicle && (vehicle.car || vehicle.van);
                const codes = vehicle && vehicle.availableEquipmentCodes;
                if (target && target.equipment) {
                  send(payload);
                } else if (Array.isArray(codes) && codes.length > 0) {
                  window.__tyreVibesPendingVehicle = payload;
                } else {
                  send(payload);
                }
              } catch (_) {}
            }

            if (requestURL.includes('vehicle-equipments')) {
              try {
                const equipments = await response.clone().json();
                const pending = window.__tyreVibesPendingVehicle;
                const vehicle = pending && pending.right && pending.right.vehicle;
                if (vehicle && Array.isArray(equipments)) {
                  const codes = (vehicle.availableEquipmentCodes || []).map(String);
                  const match = equipments.find(item => codes.includes(String(item && item.value))) || equipments[0];
                  const target = vehicle.type === 'A' ? vehicle.car : vehicle.van;
                  if (target && match && match.equipmentValue) {
                    target.equipment = match.equipmentValue;
                  }
                  send(pending);
                  window.__tyreVibesPendingVehicle = null;
                }
              } catch (_) {}
            }
            return response;
          };

          const fillPlate = () => {
            const input = document.querySelector('input[placeholder="AA123BB"], input[name*="plate" i]');
            if (!input) return false;
            if (input.value === \#(plateValue)) return true;
            input.focus();
            const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
            setter.call(input, \#(plateValue));
            input.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText', data: \#(plateValue) }));
            input.dispatchEvent(new Event('change', { bubbles: true }));
            input.blur();
            return true;
          };

          let attempts = 0;
          const attemptFill = () => {
            document.querySelector('#onetrust-accept-btn-handler')?.click();
            fillPlate();
            attempts += 1;
            if (window.__tyreVibesResponseSent || attempts >= 60) clearInterval(retryTimer);
          };
          const start = () => {
            setTimeout(attemptFill, 750);
          };
          const retryTimer = setInterval(attemptFill, 350);
          document.readyState === 'loading'
            ? document.addEventListener('DOMContentLoaded', start, { once: true })
            : start();
        })();
        """#
    }

    private static func javaScriptString(_ value: String) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: [value])
        guard
            var encoded = String(data: data, encoding: .utf8),
            encoded.count >= 2
        else {
            throw FacileWebFlowError.invalidJavaScriptValue
        }
        encoded.removeFirst()
        encoded.removeLast()
        return encoded
    }
}
