#pragma once
#include "plugin.hpp"

namespace json = boost::json;

// My RenWeb Plugin
// A RenWeb plugin.
class RenWebExamplePlugin : public RenWeb::Plugin {
public:
    explicit RenWebExamplePlugin(std::shared_ptr<RenWeb::ILogger> logger);
    ~RenWebExamplePlugin() override = default;

private:
    // Registers all callable functions into the `functions` map.
    // JS-side names follow the pattern: BIND_plugin_renweb_example_plugin_<function_name>
    void registerFunctions();
};
