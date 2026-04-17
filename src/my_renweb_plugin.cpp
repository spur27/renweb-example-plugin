// Compile Boost.JSON implementation in this TU so plugin builds
// without requiring prebuilt Boost stage libraries.
#define BOOST_JSON_SOURCE
#include <boost/json/src.hpp>

#include "../include/my_renweb_plugin.hpp"

#include <cmath>      // std::tgamma
#include <stdexcept>
#include <string>

#if defined(_WIN32) || defined(_WIN64)
    #define PLUGIN_EXPORT __declspec(dllexport)
#elif defined(__GNUC__) || defined(__clang__)
    #define PLUGIN_EXPORT __attribute__((visibility("default")))
#else
    #define PLUGIN_EXPORT
#endif

// ─── Constructor ─────────────────────────────────────────────────────────────

MyRenWebPlugin::MyRenWebPlugin(std::shared_ptr<RenWeb::ILogger> logger)
    : RenWeb::Plugin(
        "My RenWeb Plugin",
        "my_renweb_plugin",
        "0.0.1",
        "A test plugin for RenWeb demonstrating basic functionality and usage.",
        "https://github.com/spur27/renweb-example-plugin",
        logger)
{
    logger->info("[my_renweb_plugin] Initializing plugin...");
    registerFunctions();
    logger->info("[my_renweb_plugin] Plugin initialized successfully!");
}

// ─── Functions ───────────────────────────────────────────────────────────────

void MyRenWebPlugin::registerFunctions() {
    // Square a number.
    // JS: const result = await BIND_plugin_my_renweb_plugin_square(4);  // → 16
    functions["square"] = [this](const json::value& req) -> json::value {
        try {
            const json::value param = req.as_array()[0];
            if (param.is_int64()) {
                return json::value(param.as_int64() * param.as_int64());
            } else if (param.is_uint64()) {
                return json::value(param.as_uint64() * param.as_uint64());
            } else if (param.is_double()) {
                return json::value(param.as_double() * param.as_double());
            } else {
                throw std::runtime_error("Invalid parameter type. Expected a number.");
            }
        } catch (const std::exception& e) {
            this->logger->error(e.what());
            return json::value(nullptr);
        }
    };

    // Calculate factorial (uses tgamma; also accepts non-integer inputs).
    // JS: const result = await BIND_plugin_my_renweb_plugin_factorial(5);  // → 120
    functions["factorial"] = [this](const json::value& req) -> json::value {
        try {
            const json::value param = req.as_array()[0];
            double n = 0;
            if (param.is_int64())       n = static_cast<double>(param.as_int64());
            else if (param.is_uint64()) n = static_cast<double>(param.as_uint64());
            else if (param.is_double()) n = param.as_double();
            else throw std::runtime_error("Invalid parameter type. Expected a number.");
            return json::value(std::tgamma(n + 1.0));
        } catch (const std::exception& e) {
            this->logger->error(e.what());
            return json::value(nullptr);
        }
    };

    // Reverse a string.
    // Strings must be encoded with Utils.encode() on the JS side;
    // processInput() decodes the base64 representation automatically.
    // JS: const result = await BIND_plugin_my_renweb_plugin_reverse_string(Utils.encode("Hello"));  // → "olleH"
    functions["reverse_string"] = [this](const json::value& req) -> json::value {
        try {
            const json::value param = req.as_array()[0];
            const std::string input = this->processInput(param).as_string().c_str();
            std::string reversed(input.rbegin(), input.rend());
            return this->formatOutput(json::value(reversed));
        } catch (const std::exception& e) {
            this->logger->error(e.what());
            return json::value(nullptr);
        }
    };
}

// ─── Factory — keep this exact signature so RenWeb can load the plugin ────────

extern "C" PLUGIN_EXPORT RenWeb::Plugin* createPlugin(std::shared_ptr<RenWeb::ILogger> logger) {
    return new MyRenWebPlugin(logger);
}

extern "C" PLUGIN_EXPORT void destroyPlugin(RenWeb::Plugin* plugin) {
    delete plugin;
}
