#pragma once
#include "plugin.hpp"

namespace json = boost::json;

// My RenWeb Plugin
// A RenWeb plugin.
class MyRenWebPlugin : public RenWeb::Plugin {
public:
    explicit MyRenWebPlugin(std::shared_ptr<RenWeb::ILogger> logger);
    ~MyRenWebPlugin() override = default;

private:
    // Registers all callable functions into the `functions` map.
    // JS-side names follow the pattern: BIND_plugin_my_renweb_plugin_<function_name>
    void registerFunctions();
};
